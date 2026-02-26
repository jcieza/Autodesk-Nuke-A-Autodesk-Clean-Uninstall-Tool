<#
.SYNOPSIS
    Herramienta de eliminación radical para productos Autodesk (Soporte Multi-Usuario).
    Version: 2.4.0

.DESCRIPTION
    Este script elimina todas las carpetas, servicios, procesos, claves de registro y aplicaciones
    instaladas relacionadas con Autodesk de forma agresiva.
    
    ¡ADVERTENCIA! Este script no discrimina. Eliminará TODO lo que contenga "Autodesk".
    Úsalo bajo tu propia responsabilidad y como último recurso (Nuke from Orbit).

.PARAMETER AllUsers
    Limpiar los perfiles (AppData y Registro HKCU) de TODOS los usuarios de la máquina,
    cargando sus NTUSER.DAT si es necesario. (Ideal para SCCM/Intune deployments).

.NOTES
    Autor: SSM-Dealis
    Versión: 2.4.0
    Uso: Ejecutar como Administrador. Importante para la publicación en GitHub.
#>

param (
    [switch]$AllUsers
)

# -----------------------------------------------------------------------------
# 1. VERIFICACIÓN DE PRIVILEGIOS DE ADMINISTRADOR
# -----------------------------------------------------------------------------
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.BuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "[ERROR] El script no tiene privilegios de Administrador. Intentando reejecutar con privilegios..." -ForegroundColor Red
    try {
        Start-Process PowerShell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
        exit
    }
    catch {
        Write-Host "Por favor, abre PowerShell como Administrador e intenta ejecutar el script nuevamente." -ForegroundColor Yellow
        exit
    }
}
Write-Host "[OK] Ejecutando con permisos de Administrador." -ForegroundColor Green

# 1.1 CONFIGURACIÓN MULTI-USUARIO (Prompt si no se usó flag)
if (-not $PSBoundParameters.ContainsKey('AllUsers')) {
    Write-Host "`n[?] Configuracion Multi-Usuario:" -ForegroundColor Cyan
    Write-Host "Este script limpiará la base de la máquina y TU perfil de usuario actual."
    $response = Read-Host "¿Deseas limpiar también los perfiles (AppData/Registro) de TODOS los demás usuarios? (Y/N)"
    if ($response -match "^[Yy]$") {
        $AllUsers = $true
        Write-Host "   -> ¡Entendido! Se aplicará la Limpieza Nuclear a TODOS los usuarios." -ForegroundColor Yellow
    } else {
        Write-Host "   -> Limpieza limitada al usuario actual y máquina." -ForegroundColor DarkGray
    }
} else {
    Write-Host "`n[!] Flag -AllUsers detectada. Ejecutando limpieza nuclear para todos los perfiles." -ForegroundColor Yellow
}

# -----------------------------------------------------------------------------
# 2. DETENCIÓN DE PROCESOS Y SERVICIOS
# -----------------------------------------------------------------------------
# --- Paso 1: Detener Procesos y Servicios ---
Write-Host "Paso 1: Deteniendo procesos y servicios de Autodesk..." -ForegroundColor Cyan

# Procesos críticos a matar antes de desinstalar
$criticalProcesses = @("AutodeskAccess", "AdskIdentityManager", "AdSSO", "Node")
foreach ($proc in $criticalProcesses) {
    Get-Process -Name $proc -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
}

$services = Get-Service | Where-Object { $_.Name -match "Autodesk" -or $_.DisplayName -match "Autodesk" }
foreach ($srv in $services) {
    Write-Host "  Intentando detener servicio: $($srv.Name)" -ForegroundColor Yellow
    
    # Intento 1: Parada normal
    Stop-Service -Name $srv.Name -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
    
    # Verificar si se detuvo
    $currentStatus = (Get-Service -Name $srv.Name -ErrorAction SilentlyContinue).Status
    if ($currentStatus -ne 'Stopped') {
        Write-Host "  [!] El servicio $($srv.Name) se resiste (Status: $currentStatus). Forzando cierre del proceso anfitrión..." -ForegroundColor Red
        # Intento 2: Asesinato del proceso anfitrión (Ej. Node.exe anidado)
        $wmiService = Get-WmiObject -Class Win32_Service -Filter "Name='$($srv.Name)'"
        if ($wmiService -and $wmiService.ProcessId) {
            Stop-Process -Id $wmiService.ProcessId -Force -ErrorAction SilentlyContinue
            Write-Host "  [+] Proceso anfitrión PID $($wmiService.ProcessId) terminado forzosamente." -ForegroundColor Green
        } else {
             # Intento 3: taskkill genérico
             taskkill /F /FI "SERVICES eq $($srv.Name)" 2>$null
        }
    }
}

Write-Host "[OK] Procesos y servicios detenidos." -ForegroundColor Green


# -----------------------------------------------------------------------------
# 3. DESINSTALACIÓN DE PAQUETES MSI (Registro)
# -----------------------------------------------------------------------------
Write-Host "`n[PASO 2] Ejecutando desinstaladores silenciosos principales de Autodesk..." -ForegroundColor Cyan

# Desinstalador AdksUninstallHelper (Nuevas versiones 2024+)
$uninstallersPath = "$env:ProgramData\Autodesk\Uninstallers"
if (Test-Path $uninstallersPath) {
    Write-Host "   Buscando desinstaladores adicionales AdksUninstallHelper (ODIS)..." -ForegroundColor DarkGray
    $helpers = Get-ChildItem -Path $uninstallersPath -Recurse -Filter "AdksUninstallHelper.exe" -ErrorAction SilentlyContinue
    foreach ($helper in $helpers) {
        Write-Host "   Ejecutando helper de desinstalación en: $($helper.Directory.Name)" -ForegroundColor Yellow
        Start-Process -FilePath "`"$($helper.FullName)`"" -Wait -NoNewWindow -ErrorAction SilentlyContinue
    }
}

# Desinstalador ODIS / Access directo (si existe)
$odisUninstaller = "C:\Program Files\Autodesk\AdODIS\V1\RemoveODIS.exe"
if (Test-Path $odisUninstaller) {
    Write-Host "   Desinstalando Autodesk Access / ODIS..." -ForegroundColor Yellow
    Start-Process -FilePath $odisUninstaller -ArgumentList "-q" -Wait -NoNewWindow -ErrorAction SilentlyContinue
}

# Desinstalador AdskLicensing directo (si existe)
$licUninstaller = "C:\Program Files (x86)\Common Files\Autodesk Shared\AdskLicensing\uninstall.exe"
if (Test-Path $licUninstaller) {
    Write-Host "   Desinstalando Autodesk Licensing Service..." -ForegroundColor Yellow
    Start-Process -FilePath "`"$licUninstaller`"" -ArgumentList "--mode unattended" -Wait -NoNewWindow -ErrorAction SilentlyContinue
}

# Desinstalador Autodesk Identity Manager directo (si existe)
$idUninstaller = "C:\Program Files\Autodesk\Autodesk Identity Manager\uninstall.exe"
if (Test-Path $idUninstaller) {
    Write-Host "   Desinstalando Autodesk Identity Manager..." -ForegroundColor Yellow
    Start-Process -FilePath "`"$idUninstaller`"" -ArgumentList "--mode unattended" -Wait -NoNewWindow -ErrorAction SilentlyContinue
}

Write-Host "Buscando y ejecutando otros desinstaladores (MSI/Registro)..." -ForegroundColor Cyan

$registryPaths = @(
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
)

Get-ItemProperty $registryPaths -ErrorAction SilentlyContinue | 
Where-Object { ($_.DisplayName -match "Autodesk" -or $_.Publisher -match "Autodesk") -and ($_.UninstallString) } | 
ForEach-Object {
    $uninstallString = $_.UninstallString
    $displayName = $_.DisplayName
    
    if ($uninstallString -match "msiexec") {
        $arguments = ($uninstallString -ireplace "msiexec.exe","" -ireplace "/I","/X") + " /quiet /qn /norestart"
        Write-Host "   Desinstalando MSI: $displayName" -ForegroundColor Yellow
        Start-Process "msiexec.exe" -ArgumentList $arguments -Wait -NoNewWindow -ErrorAction SilentlyContinue
    }
    elseif ($uninstallString -match "Installer.exe") {
        # Extraer ejecutable ODIS y ejecutar silencioso
        $exePath = $uninstallString.Split("-")[0].Trim(' ', '"')
        if (Test-Path $exePath) {
            $mIndex = $uninstallString.IndexOf("-m")
            $extraArgs = if ($mIndex -gt 0) { $uninstallString.Substring($mIndex) } else { "" }
            $arguments = "-q -i uninstall --trigger_point system $extraArgs"
            Write-Host "   Desinstalando ODIS: $displayName" -ForegroundColor Yellow
            Start-Process -FilePath "`"$exePath`"" -ArgumentList $arguments -Wait -NoNewWindow -ErrorAction SilentlyContinue
        }
    }
}

Write-Host "[OK] Intento de desinstalación de paquetes finalizado." -ForegroundColor Green

# -----------------------------------------------------------------------------
# 10. LIMPIEZA DEL REGISTRO DE USUARIOS ESPECÍFICOS (HKCU / NTUSER.DAT)
# -----------------------------------------------------------------------------
Write-Host "`n[PASO 10] Limpiando claves de registro de los perfiles de usuario..." -ForegroundColor Cyan

$hkcuPaths = @(
    "Software\Autodesk",
    "Software\Microsoft\Windows\CurrentVersion\Applets\Paint\Recent File List" # A veces Autodesk deja archivos recntes aquí
)

if ($AllUsers) {
    Write-Host "   Iniciando barrido profundo de registro para TODOS los perfiles (Cargando Hives)..." -ForegroundColor Yellow
    # Limpiamos todos los perfiles de usuario montando sus NTUSER.DAT
    $userProfiles = Get-ChildItem -Path "C:\Users" -Directory -Exclude "Public", "Default User"
    
    foreach ($profile in $userProfiles) {
        $ntuserPath = Join-Path $profile.FullName "NTUSER.DAT"
        if (Test-Path $ntuserPath) {
            # Verificar si el hive ya está cargado por el usuario actual
            $isCurrentUser = ($profile.Name -eq $env:USERNAME)
            $hiveKey = "HKU_Temp_$($profile.Name)"
            
            if ($isCurrentUser) {
                # Para el usuario actual, usar HKCU normal
                foreach ($subPath in $hkcuPaths) {
                    $fullPath = "HKCU:\$subPath"
                    if (Test-Path $fullPath) {
                        Write-Host "   Borrando $fullPath (Usuario Actual)" -ForegroundColor DarkGray
                        Remove-Item -Path $fullPath -Recurse -Force -ErrorAction SilentlyContinue
                    }
                }
            } else {
                # Cargar hive offline silenciosamente
                reg.exe load "HKU\$hiveKey" "$ntuserPath" > $null 2>&1
                if ($LASTEXITCODE -eq 0) {
                    Write-Host "   [$($profile.Name)] Hive Montado. Limpiando registro..." -ForegroundColor DarkGray
                    foreach ($subPath in $hkcuPaths) {
                        $fullPath = "Registry::HKEY_USERS\$hiveKey\$subPath"
                        if (Test-Path $fullPath) {
                            Remove-Item -Path $fullPath -Recurse -Force -ErrorAction SilentlyContinue
                        }
                    }
                    # Descargar hive y correr garbage collector para soltar hooks
                    [gc]::collect()
                    Start-Sleep -Seconds 1
                    reg.exe unload "HKU\$hiveKey" > $null 2>&1
                }
            }
        }
    }
} else {
    # Limpieza estándar del usuario actual
    foreach ($subPath in $hkcuPaths) {
        $fullPath = "HKCU:\$subPath"
        if (Test-Path $fullPath) {
            Write-Host "   Borrando $fullPath (Usuario Actual)" -ForegroundColor DarkGray
            Remove-Item -Path $fullPath -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}


# -----------------------------------------------------------------------------
# 11. LIMPIEZA FINAL Y VACIADO DE PAPELERA
# -----------------------------------------------------------------------------
Write-Host "`n[PASO 11] Vaciando la papelera y finalizando..." -ForegroundColor Cyan

# Descubrimiento dinámico de rutas en discos secundarios
Write-Host "   Buscando rutas de instalación dinámicas en el registro..." -ForegroundColor DarkGray
$dynamicDirs = @()
$uninstallPaths = @(
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
)

foreach ($path in $uninstallPaths) {
    $keys = Get-ItemProperty $path -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -match "Autodesk" -or $_.Publisher -match "Autodesk" }
    foreach ($key in $keys) {
        if (![string]::IsNullOrEmpty($key.InstallLocation) -and (Test-Path $key.InstallLocation)) {
            $dynamicDirs += $key.InstallLocation
        }
    }
}

if ($dynamicDirs.Count -gt 0) {
    $dynamicDirs = $dynamicDirs | Select-Object -Unique
    Write-Host "   Se encontraron $($dynamicDirs.Count) rutas personalizadas/secundarias." -ForegroundColor Yellow
}

$dirs = @(
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

# Añadir AppData del usuario(s)
if ($AllUsers) {
    Write-Host "   Añadiendo directorios AppData de TODOS los usuarios al escaneo..." -ForegroundColor DarkGray
    $userProfiles = Get-ChildItem -Path "C:\Users" -Directory -Exclude "Public"
    foreach ($profile in $userProfiles) {
        $dirs += "$($profile.FullName)\AppData\Local\Autodesk"
        $dirs += "$($profile.FullName)\AppData\Roaming\Autodesk"
    }
} else {
    $dirs += "$env:LOCALAPPDATA\Autodesk"
    $dirs += "$env:APPDATA\Autodesk"
}

# Fusionar y limpiar duplicados
$allDirs = ($dirs + $dynamicDirs) | Select-Object -Unique

foreach ($dir in $allDirs) {
    if (Test-Path $dir) {
        Write-Host "   Eliminando: $dir" -ForegroundColor DarkGray
        try {
            Remove-Item -Path $dir -Recurse -Force -ErrorAction SilentlyContinue
        } catch {
            Write-Host "      [!] No se pudo eliminar completamente: $dir" -ForegroundColor Red
        }
    } 
}

Write-Host "[OK] Carpetas residuales procesadas." -ForegroundColor Green


# -----------------------------------------------------------------------------
# 5. LIMPIEZA DE REGISTRO Y REINICIO DE BUCLE
# -----------------------------------------------------------------------------
Write-Host "`n[PASO 6] Limpiando el Registro de Windows y solucionando bucles de reinicio..." -ForegroundColor Cyan

# Eliminar claves principales de Autodesk
$regKeys = @(
    "HKLM:\SOFTWARE\Autodesk",
    "HKCU:\SOFTWARE\Autodesk",
    "HKLM:\SOFTWARE\Wow6432Node\Autodesk",
    "HKCR:\Autodesk"
)

foreach ($key in $regKeys) {
    if (Test-Path $key) {
        Write-Host "   Eliminando clave de registro: $key" -ForegroundColor DarkGray
        Remove-Item -Path $key -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# -----------------------------------------------------------------------------
# 5B. ELIMINACIÓN DE ENTRADAS FANTASMA (AGREGAR O QUITAR PROGRAMAS)
# -----------------------------------------------------------------------------
Write-Host "   Buscando y eliminando registros huérfanos de desinstalación..." -ForegroundColor DarkGray
$uninstallRegistryPaths = @(
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"
)

Get-ItemProperty $uninstallRegistryPaths -ErrorAction SilentlyContinue | 
Where-Object { $_.DisplayName -match "Autodesk" -or $_.Publisher -match "Autodesk" } | 
ForEach-Object {
    Write-Host "   Eliminando registro fantasma: $($_.DisplayName)" -ForegroundColor Yellow
    Remove-Item -Path $_.PSPath -Recurse -Force -ErrorAction SilentlyContinue
}

# Solucionar Loop de Reinicio ("PendingFileRenameOperations")
$sessionManagerPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager"
$pendingFileRename = Get-ItemProperty -Path $sessionManagerPath -Name "PendingFileRenameOperations" -ErrorAction SilentlyContinue
if ($pendingFileRename) {
    Write-Host "   [ATENCION] Se encontró la clave 'PendingFileRenameOperations'. Eliminándola para arreglar el bucle de reinicio..." -ForegroundColor Yellow
    Remove-ItemProperty -Path $sessionManagerPath -Name "PendingFileRenameOperations" -Force -ErrorAction SilentlyContinue
}

# Solucionar Loop de Reinicio ("RebootRequired") en Windows Update
$rebootRequiredPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update"
if (Test-Path "$rebootRequiredPath\RebootRequired") {
    Write-Host "   [ATENCION] Se encontró la clave 'RebootRequired'. Eliminándola..." -ForegroundColor Yellow
    Remove-ItemProperty -Path $rebootRequiredPath -Name "RebootRequired" -Force -ErrorAction SilentlyContinue
}

Write-Host "[OK] Registro limpio y bucles de reinicio mitigados." -ForegroundColor Green

# -----------------------------------------------------------------------------
# FIN DEL SCRIPT
# -----------------------------------------------------------------------------
Write-Host "`n======================================================================" -ForegroundColor Cyan
Write-Host "  LIMPIEZA FINALIZADA CON ÉXITO " -ForegroundColor Green
Write-Host "  El sistema está listo para una instalación limpia de Autodesk." -ForegroundColor White
Write-Host "  Aun así, se recomienda reiniciar la PC ANTES de intentar instalar." -ForegroundColor Yellow
Write-Host "======================================================================`n" -ForegroundColor Cyan
