# Autodesk-Nuke Improved Script
# Versión refactorizada con funciones, manejo de errores y registro centralizado.

# ------------------------------------------------------------
# Configuración inicial
# ------------------------------------------------------------
$LogPath = "$env:ProgramData\AutodeskNuke\log.txt"
function Write-Log {
    param([string]$Message, [string]$Level = 'INFO')
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $entry = "[$timestamp] [$Level] $Message"
    Add-Content -Path $LogPath -Value $entry
    if ($Level -eq 'ERROR') { Write-Error $Message } else { Write-Host $Message }
}

# ------------------------------------------------------------
# Verificar privilegios de administrador
# ------------------------------------------------------------
function Ensure-Admin {
    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.BuiltInRole]::Administrator)
    if (-not $isAdmin) {
        Write-Log "[ERROR] No se está ejecutando como Administrador. Reejecutando..." 'ERROR'
        try {
            Start-Process PowerShell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs -Wait
            exit
        } catch {
            Write-Log "No se pudo relanzar como Administrador. Abortando." 'ERROR'
            exit 1
        }
    } else {
        Write-Log "[OK] Ejecutando con privilegios de Administrador."
    }
}

# ------------------------------------------------------------
# Parámetro de multi‑usuario
# ------------------------------------------------------------
param(
    [switch]$AllUsers
)

function Prompt-MultiUser {
    if (-not $PSBoundParameters.ContainsKey('AllUsers')) {
        Write-Host "`n[?] Configuración Multi‑Usuario:" -ForegroundColor Cyan
        $response = Read-Host "¿Deseas limpiar también los perfiles de TODOS los demás usuarios? (Y/N)"
        if ($response -match '^[Yy]$') { $script:AllUsers = $true; Write-Log "Flag -AllUsers activado por interacción del usuario." }
    } else {
        Write-Log "Flag -AllUsers detectada en la línea de comandos."
    }
}

# ------------------------------------------------------------
# Detener procesos críticos de Autodesk
# ------------------------------------------------------------
function Stop-AutodeskProcesses {
    $critical = @('AutodeskAccess','AdskIdentityManager','AdSSO','Node')
    foreach ($p in $critical) {
        Get-Process -Name $p -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    }
    Write-Log "Procesos críticos detenidos."
}

# ------------------------------------------------------------
# Detener servicios de Autodesk
# ------------------------------------------------------------
function Remove-AutodeskServices {
    $services = Get-Service | Where-Object { $_.Name -match 'Autodesk' -or $_.DisplayName -match 'Autodesk' }
    foreach ($svc in $services) {
        try {
            Stop-Service -Name $svc.Name -Force -ErrorAction Stop
            Write-Log "Servicio $($svc.Name) detenido correctamente."
        } catch {
            Write-Log "Fallo al detener $($svc.Name). Intentando matar proceso host..." 'WARNING'
            $wmi = Get-WmiObject -Class Win32_Service -Filter "Name='$($svc.Name)'"
            if ($wmi -and $wmi.ProcessId) {
                Stop-Process -Id $wmi.ProcessId -Force -ErrorAction SilentlyContinue
                Write-Log "Proceso host PID $($wmi.ProcessId) terminado."
            } else {
                taskkill /F /FI "SERVICES eq $($svc.Name)" 2>$null
                Write-Log "taskkill ejecutado para $($svc.Name)."
            }
        }
    }
    Write-Log "Servicios de Autodesk procesados."
}

# ------------------------------------------------------------
# Desinstalar paquetes MSI y ejecutables
# ------------------------------------------------------------
function Uninstall-MsiPackages {
    $registryPaths = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
    )
    foreach ($path in $registryPaths) {
        Get-ItemProperty $path -ErrorAction SilentlyContinue | Where-Object {
            ($_.DisplayName -match 'Autodesk' -or $_.Publisher -match 'Autodesk') -and $_.UninstallString
        } | ForEach-Object {
            $uninstall = $_.UninstallString
            if ($uninstall -match 'msiexec') {
                $args = ($uninstall -replace 'msiexec.exe','' -replace '/I','/X') + ' /quiet /qn /norestart'
                Write-Log "Desinstalando MSI: $($_.DisplayName)"
                Start-Process 'msiexec.exe' -ArgumentList $args -Wait -NoNewWindow -ErrorAction SilentlyContinue
            } elseif ($uninstall -match 'Installer.exe') {
                $exePath = $uninstall.Split('-')[0].Trim(' "')
                if (Test-Path $exePath) {
                    $extra = if ($uninstall -match '-m') { $uninstall.Substring($uninstall.IndexOf('-m')) } else { '' }
                    $args = "-q -i uninstall --trigger_point system $extra"
                    Write-Log "Desinstalando ODIS: $($_.DisplayName)"
                    Start-Process -FilePath $exePath -ArgumentList $args -Wait -NoNewWindow -ErrorAction SilentlyContinue
                }
            }
        }
    }
    Write-Log "Desinstalación de paquetes completada."
}

# ------------------------------------------------------------
# Limpieza de registro de usuarios (HKCU / NTUSER.DAT)
# ------------------------------------------------------------
function Clean-UserHive {
    $hkcuPaths = @('Software\Autodesk','Software\Microsoft\Windows\CurrentVersion\Applets\Paint\Recent File List')
    if ($AllUsers) {
        $profiles = Get-ChildItem -Path 'C:\Users' -Directory -Exclude 'Public','Default User'
        foreach ($profile in $profiles) {
            $ntUser = Join-Path $profile.FullName 'NTUSER.DAT'
            if (Test-Path $ntUser) {
                if ($profile.Name -eq $env:USERNAME) {
                    foreach ($sub in $hkcuPaths) { Remove-Item -Path "HKCU:\$sub" -Recurse -Force -ErrorAction SilentlyContinue }
                } else {
                    $hiveKey = "HKU_Temp_$($profile.Name)"
                    reg.exe load "HKU\$hiveKey" "$ntUser" >$null 2>&1
                    if ($LASTEXITCODE -eq 0) {
                        foreach ($sub in $hkcuPaths) {
                            $full = "Registry::HKEY_USERS\\$hiveKey\\$sub"
                            Remove-Item -Path $full -Recurse -Force -ErrorAction SilentlyContinue
                        }
                        reg.exe unload "HKU\\$hiveKey" >$null 2>&1
                    }
                }
            }
        }
    } else {
        foreach ($sub in $hkcuPaths) { Remove-Item -Path "HKCU:\$sub" -Recurse -Force -ErrorAction SilentlyContinue }
    }
    Write-Log "Limpieza de registro de usuarios completada."
}

# ------------------------------------------------------------
# Eliminación de directorios residuales
# ------------------------------------------------------------
function Remove-Directories {
    $staticDirs = @(
        "C:\Program Files\Autodesk",
        "C:\Program Files\Common Files\Autodesk Shared",
        "C:\Program Files (x86)\Autodesk",
        "C:\Program Files (x86)\Common Files\Autodesk Shared",
        "C:\ProgramData\Autodesk",
        "C:\Users\Public\Documents\Autodesk",
        "C:\Users\Public\Autodesk",
        "$env:TEMP",
        "$env:WINDIR\Temp",
        "$env:ProgramData\FLEXnet\adsk*",
        "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Autodesk"
    )
    $dirs = $staticDirs
    if ($AllUsers) {
        $profiles = Get-ChildItem -Path 'C:\Users' -Directory -Exclude 'Public'
        foreach ($p in $profiles) {
            $dirs += "$($p.FullName)\AppData\Local\Autodesk"
            $dirs += "$($p.FullName)\AppData\Roaming\Autodesk"
        }
    } else {
        $dirs += "$env:LOCALAPPDATA\Autodesk"
        $dirs += "$env:APPDATA\Autodesk"
    }
    $unique = $dirs | Select-Object -Unique
    foreach ($d in $unique) {
        if (Test-Path $d) {
            try { Remove-Item -Path $d -Recurse -Force -ErrorAction SilentlyContinue; Write-Log "Eliminado $d" }
            catch { Write-Log "No se pudo eliminar $d" 'WARNING' }
        }
    }
    Write-Log "Eliminación de directorios completada."
}

# ------------------------------------------------------------
# Reparar bucles de reinicio (PendingFileRenameOperations, RebootRequired)
# ------------------------------------------------------------
function Fix-RebootLoops {
    $sessionMgr = 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager'
    $pending = Get-ItemProperty -Path $sessionMgr -Name 'PendingFileRenameOperations' -ErrorAction SilentlyContinue
    if ($pending) { Remove-ItemProperty -Path $sessionMgr -Name 'PendingFileRenameOperations' -Force; Write-Log "PendingFileRenameOperations eliminado." }
    $rebootPath = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update'
    if (Test-Path "$rebootPath\RebootRequired") { Remove-ItemProperty -Path $rebootPath -Name 'RebootRequired' -Force; Write-Log "RebootRequired eliminado." }
    Write-Log "Bucle de reinicio mitigado."
}

# ------------------------------------------------------------
# Función principal
# ------------------------------------------------------------
function Main {
    Ensure-Admin
    Prompt-MultiUser
    Stop-AutodeskProcesses
    Remove-AutodeskServices
    Uninstall-MsiPackages
    Clean-UserHive
    Remove-Directories
    Fix-RebootLoops
    Write-Log "\n======================================================================\n  LIMPIEZA FINALIZADA CON ÉXITO\n  El sistema está listo para una instalación limpia de Autodesk.\n  Se recomienda reiniciar la PC antes de intentar instalar.\n======================================================================" 'INFO'
}

# Ejecutar
Main
