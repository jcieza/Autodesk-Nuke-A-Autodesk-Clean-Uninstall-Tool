<#
.SYNOPSIS
    Herramienta de eliminación Autodesk v4.0 "Equilibrada"
    
.DESCRIPTION
    Script optimizado que combina seguridad, funcionalidad y mantenibilidad.
    Basado en análisis de 5 versiones previas, implementa únicamente características
    de impacto real sin sobre-ingeniería.
    
    Características clave:
    - Logging persistente con niveles
    - Modo DryRun para previsualización
    - Multi-usuario robusto
    - Filtrado inteligente de operaciones peligrosas
    - Limpieza de tareas programadas
    
.PARAMETER AllUsers
    Limpiar perfiles AppData y registro de TODOS los usuarios.
    
.PARAMETER DryRun
    Simular sin realizar cambios reales. Útil para auditoría y testing.
    
.PARAMETER LogPath
    Ruta personalizada para archivo de log. Por defecto: $env:TEMP
    
.EXAMPLE
    .\Autodesk-Nuke-Equilibrada-v4.0.ps1 -AllUsers
    .\Autodesk-Nuke-Equilibrada-v4.0.ps1 -DryRun
    
.NOTES
    Versión: 4.0.0-Equilibrada
    Autor: Contribuidor de Comunidad
    Requisitos: PowerShell 5.0+, Permisos de Administrador
#>

param(
    [switch]$AllUsers,
    [switch]$DryRun,
    [string]$LogPath = "$env:TEMP\Autodesk-Nuke-v4.0_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
)

$ErrorActionPreference = "Continue"
Set-StrictMode -Version 2.0

# ════════════════════════════════════════════════════════════════════
# FUNCIONES DE UTILIDAD
# ════════════════════════════════════════════════════════════════════

function Write-Log {
    param(
        [string]$Message,
        [ValidateSet("INFO", "SUCCESS", "WARNING", "ERROR", "DEBUG")][string]$Level = "INFO"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    
    # Escribir a archivo
    Add-Content -Path $LogPath -Value $logEntry -Encoding UTF8 -ErrorAction SilentlyContinue
    
    # Escribir a consola con color
    $colors = @{
        INFO    = "Cyan"
        SUCCESS = "Green"
        WARNING = "Yellow"
        ERROR   = "Red"
        DEBUG   = "Gray"
    }
    
    Write-Host $logEntry -ForegroundColor $colors[$Level]
}

function Initialize-Logging {
    "═════════════════════════════════════════════════════════════" | Out-File $LogPath -Encoding UTF8
    "Autodesk-Nuke v4.0 Equilibrada - Inicio: $(Get-Date)" | Out-File $LogPath -Append -Encoding UTF8
    "Sistema: Windows $(([System.Environment]::OSVersion.Version).Major).$(([System.Environment]::OSVersion.Version).Minor)" | Out-File $LogPath -Append -Encoding UTF8
    "Usuario: $env:USERNAME | Máquina: $env:COMPUTERNAME | Modo: $(if($DryRun){'DRY-RUN'}else{'EJECUCIÓN REAL'})" | Out-File $LogPath -Append -Encoding UTF8
    "═════════════════════════════════════════════════════════════" | Out-File $LogPath -Append -Encoding UTF8
    
    Write-Log "Log inicializado en: $LogPath"
}

function Test-AdminPrivileges {
    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.BuiltInRole]::Administrator)
    
    if (-not $isAdmin) {
        Write-Log "Elevando privilegios..." -Level WARNING
        try {
            $argList = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
            if ($AllUsers) { $argList += " -AllUsers" }
            if ($DryRun) { $argList += " -DryRun" }
            if ($LogPath) { $argList += " -LogPath `"$LogPath`"" }
            
            Start-Process PowerShell -ArgumentList $argList -Verb RunAs -Wait
            exit 0
        }
        catch {
            Write-Log "Elevación fallida. Ejecuta manualmente como Admin." -Level ERROR
            exit 1
        }
    }
    
    Write-Log "✓ Ejecutando con privilegios de Administrador" -Level SUCCESS
}

function Request-UserConfirmation {
    Write-Host "`n" -ForegroundColor Yellow
    Write-Host "╔════════════════════════════════════════════════════════╗" -ForegroundColor Yellow
    Write-Host "║ ⚠️  ADVERTENCIA: OPERACIÓN DESTRUCTIVA" -ForegroundColor Yellow
    Write-Host "╚════════════════════════════════════════════════════════╝" -ForegroundColor Yellow
    Write-Host "Este script eliminará TODOS los rastros de Autodesk." -ForegroundColor Yellow
    Write-Host "Esta acción es IRREVERSIBLE." -ForegroundColor Yellow
    Write-Host ""
    
    if ($DryRun) {
        Write-Host "Modo: DRY-RUN (no se realizarán cambios)" -ForegroundColor Green
        Write-Host ""
        return $true
    }
    
    Write-Host "Escribe 'eliminar autodesk' para confirmar (sin comillas):" -ForegroundColor Yellow
    $response = Read-Host "Confirmación"
    
    if ($response -ne "eliminar autodesk") {
        Write-Log "Operación cancelada por usuario" -Level INFO
        exit 0
    }
    
    return $true
}

function Invoke-SafeOperation {
    param(
        [string]$Description,
        [scriptblock]$Operation,
        [ref]$Counter
    )
    
    if ($DryRun) {
        Write-Log "[DRY-RUN] $Description" -Level INFO
        $Counter.Value++
        return $true
    }
    
    try {
        Write-Log "Ejecutando: $Description" -Level INFO
        $null = & $Operation
        Write-Log "✓ Completado: $Description" -Level SUCCESS
        $Counter.Value++
        return $true
    }
    catch {
        Write-Log "✗ Error en $Description : $($_.Exception.Message)" -Level ERROR
        return $false
    }
}

# ════════════════════════════════════════════════════════════════════
# FASE 1: PROCESOS Y SERVICIOS
# ════════════════════════════════════════════════════════════════════

function Stop-AutodeskProcesses {
    Write-Log "═ FASE 1: Deteniendo procesos Autodesk..." -Level INFO
    
    $processesStopped = 0
    $criticalProcesses = @("AutodeskAccess", "AdskIdentityManager", "AdSSO", "AdLM", "Node")
    
    foreach ($procName in $criticalProcesses) {
        $processes = @(Get-Process -Name $procName -ErrorAction SilentlyContinue)
        
        foreach ($proc in $processes) {
            Invoke-SafeOperation "Detener proceso: $($proc.Name) (PID: $($proc.Id))" {
                if (-not $DryRun) { $proc | Stop-Process -Force -ErrorAction Stop }
            } ([ref]$processesStopped) | Out-Null
        }
    }
    
    Write-Log "✓ Procesos detenidos: $processesStopped" -Level SUCCESS
    return $processesStopped
}

function Stop-AutodeskServices {
    Write-Log "═ FASE 2: Deteniendo servicios Autodesk..." -Level INFO
    
    $servicesStopped = 0
    $services = @(Get-Service -ErrorAction SilentlyContinue | 
        Where-Object { $_.Name -match "Autodesk|Adsk|SSO|FlexNet" -or $_.DisplayName -match "Autodesk" })
    
    foreach ($svc in $services) {
        Invoke-SafeOperation "Detener servicio: $($svc.Name)" {
            $svc | Stop-Service -Force -ErrorAction Stop
            Start-Sleep -Milliseconds 500
            
            # Si sigue activo, matar proceso
            if ((Get-Service -Name $svc.Name -ErrorAction SilentlyContinue).Status -eq 'Running') {
                $cim = Get-CimInstance -ClassName Win32_Service -Filter "Name='$($svc.Name)'" -ErrorAction SilentlyContinue
                if ($cim.ProcessId -gt 0) {
                    Stop-Process -Id $cim.ProcessId -Force -ErrorAction SilentlyContinue
                }
            }
        } ([ref]$servicesStopped) | Out-Null
    }
    
    Write-Log "✓ Servicios detenidos: $servicesStopped" -Level SUCCESS
    return $servicesStopped
}

# ════════════════════════════════════════════════════════════════════
# FASE 3: DESINSTALACIÓN MSI
# ════════════════════════════════════════════════════════════════════

function Uninstall-MsiPackages {
    Write-Log "═ FASE 3: Ejecutando desinstaladores MSI..." -Level INFO
    
    $uninstallCount = 0
    $regPaths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )
    
    $packages = Get-ItemProperty $regPaths -ErrorAction SilentlyContinue | 
        Where-Object { ($_.DisplayName -match "Autodesk" -or $_.Publisher -match "Autodesk") -and $_.UninstallString }
    
    foreach ($pkg in $packages) {
        Write-Log "Desinstalando: $($pkg.DisplayName)" -Level INFO
        
        if ($pkg.UninstallString -match "msiexec") {
            $args = ($pkg.UninstallString -ireplace "msiexec.exe","" -ireplace "/I","/X") + " /quiet /qn /norestart"
            Invoke-SafeOperation "MSI: $($pkg.DisplayName)" {
                Start-Process "msiexec.exe" -ArgumentList $args -Wait -NoNewWindow -ErrorAction Stop
            } ([ref]$uninstallCount) | Out-Null
        }
        elseif ($pkg.UninstallString -match "Installer.exe") {
            $exePath = $pkg.UninstallString.Split("-")[0].Trim(' "')
            if (Test-Path $exePath) {
                Invoke-SafeOperation "ODIS: $($pkg.DisplayName)" {
                    Start-Process -FilePath $exePath -ArgumentList "-q -i uninstall" -Wait -NoNewWindow -ErrorAction Stop
                } ([ref]$uninstallCount) | Out-Null
            }
        }
    }
    
    Write-Log "✓ Paquetes desinstalados: $uninstallCount" -Level SUCCESS
    return $uninstallCount
}

# ════════════════════════════════════════════════════════════════════
# FASE 4: REGISTRO (HKLM / HKCR)
# ════════════════════════════════════════════════════════════════════

function Clear-RegistryKeys {
    Write-Log "═ FASE 4: Limpiando registro global (HKLM/HKCR)..." -Level INFO
    
    $registryCount = 0
    $keys = @("HKLM:\SOFTWARE\Autodesk", "HKLM:\SOFTWARE\Wow6432Node\Autodesk", "HKCR:\Autodesk")
    
    foreach ($key in $keys) {
        if (Test-Path $key) {
            Invoke-SafeOperation "Eliminar clave: $key" {
                Remove-Item -Path $key -Recurse -Force -ErrorAction Stop
            } ([ref]$registryCount) | Out-Null
        }
    }
    
    # Limpiar entradas fantasma
    $uninstallPaths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )
    
    Get-ItemProperty $uninstallPaths -ErrorAction SilentlyContinue | 
        Where-Object { $_.DisplayName -match "Autodesk" } | 
        ForEach-Object {
            Invoke-SafeOperation "Eliminar entrada: $($_.DisplayName)" {
                Remove-Item -Path $_.PSPath -Force -ErrorAction Stop
            } ([ref]$registryCount) | Out-Null
        }
    
    Write-Log "✓ Claves de registro eliminadas: $registryCount" -Level SUCCESS
    return $registryCount
}

# ════════════════════════════════════════════════════════════════════
# FASE 5: PERFILES DE USUARIO (HKCU / NTUSER.DAT)
# ════════════════════════════════════════════════════════════════════

function Clear-UserProfiles {
    Write-Log "═ FASE 5: Limpiando perfiles de usuario..." -Level INFO
    
    $profilesCount = 0
    
    if ($AllUsers) {
        Write-Log "Modo multi-usuario: limpiando TODOS los perfiles" -Level INFO
        
        $userProfiles = Get-ChildItem "C:\Users" -Directory -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -notmatch "^(Public|Default|NetworkService)" }
        
        foreach ($profile in $userProfiles) {
            $ntuserPath = Join-Path $profile.FullName "NTUSER.DAT"
            
            if (-not (Test-Path $ntuserPath)) { continue }
            
            if ($profile.Name -eq $env:USERNAME) {
                # Usuario actual: limpiar directo desde HKCU
                Remove-Item "HKCU:\Software\Autodesk" -Recurse -Force -ErrorAction SilentlyContinue
                $profilesCount++
            }
            else {
                # Usuario offline: montar hive
                $hiveKey = "TEMP_$($profile.Name)"
                Write-Log "  Procesando perfil offline: $($profile.Name)" -Level DEBUG
                
                $loadResult = & cmd /c "reg load HKU\$hiveKey `"$ntuserPath`"" 2>&1
                if ($LASTEXITCODE -eq 0) {
                    try {
                        $regPath = "Registry::HKEY_USERS\$hiveKey\Software\Autodesk"
                        if (Test-Path $regPath) {
                            if (-not $DryRun) {
                                Remove-Item -Path $regPath -Recurse -Force -ErrorAction SilentlyContinue
                            }
                        }
                        $profilesCount++
                    }
                    finally {
                        # Descargar hive con reintentos
                        [gc]::Collect()
                        [gc]::WaitForPendingFinalizers()
                        Start-Sleep -Milliseconds 500
                        & cmd /c "reg unload HKU\$hiveKey" 2>$null | Out-Null
                    }
                }
            }
        }
    }
    else {
        # Solo usuario actual
        Remove-Item "HKCU:\Software\Autodesk" -Recurse -Force -ErrorAction SilentlyContinue
        $profilesCount++
    }
    
    Write-Log "✓ Perfiles de usuario procesados: $profilesCount" -Level SUCCESS
    return $profilesCount
}

# ════════════════════════════════════════════════════════════════════
# FASE 6: DIRECTORIOS Y CARPETAS
# ════════════════════════════════════════════════════════════════════

function Remove-AutodeskFolders {
    Write-Log "═ FASE 6: Eliminando carpetas residuales..." -Level INFO
    
    $foldersCount = 0
    $baseDirs = @(
        "C:\Program Files\Autodesk",
        "C:\Program Files (x86)\Autodesk",
        "C:\ProgramData\Autodesk",
        "$env:ProgramData\FLEXnet"
    )
    
    # Agregar AppData de usuarios
    if ($AllUsers) {
        $userProfiles = Get-ChildItem "C:\Users" -Directory -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -notmatch "^(Public|Default)" }
        
        foreach ($profile in $userProfiles) {
            $baseDirs += "$($profile.FullName)\AppData\Local\Autodesk"
            $baseDirs += "$($profile.FullName)\AppData\Roaming\Autodesk"
        }
    }
    else {
        $baseDirs += "$env:LOCALAPPDATA\Autodesk"
        $baseDirs += "$env:APPDATA\Autodesk"
    }
    
    # Limpieza segura de TEMP
    if (Test-Path $env:TEMP) {
        $tempAutodesk = Get-ChildItem -Path $env:TEMP -Directory -Filter "*Autodesk*" -ErrorAction SilentlyContinue
        $baseDirs += $tempAutodesk.FullName
    }
    
    # Eliminar duplicados y ejecutar
    $baseDirs = $baseDirs | Select-Object -Unique
    
    foreach ($dir in $baseDirs) {
        if (Test-Path $dir) {
            Invoke-SafeOperation "Eliminar carpeta: $dir" {
                Remove-Item -Path $dir -Recurse -Force -ErrorAction Stop
            } ([ref]$foldersCount) | Out-Null
        }
    }
    
    Write-Log "✓ Carpetas eliminadas: $foldersCount" -Level SUCCESS
    return $foldersCount
}

# ════════════════════════════════════════════════════════════════════
# FASE 7: TAREAS PROGRAMADAS
# ════════════════════════════════════════════════════════════════════

function Remove-ScheduledTasks {
    Write-Log "═ FASE 7: Eliminando tareas programadas..." -Level INFO
    
    $tasksCount = 0
    $tasks = @(Get-ScheduledTask -TaskPath "\Autodesk*" -ErrorAction SilentlyContinue)
    
    foreach ($task in $tasks) {
        Invoke-SafeOperation "Eliminar tarea: $($task.TaskName)" {
            Unregister-ScheduledTask -TaskName $task.TaskName -Confirm:$false -ErrorAction Stop
        } ([ref]$tasksCount) | Out-Null
    }
    
    Write-Log "✓ Tareas programadas eliminadas: $tasksCount" -Level SUCCESS
    return $tasksCount
}

# ════════════════════════════════════════════════════════════════════
# FASE 8: BUCLES DE REINICIO
# ════════════════════════════════════════════════════════════════════

function Fix-RebootLoops {
    Write-Log "═ FASE 8: Mitigando bucles de reinicio..." -Level INFO
    
    $smPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager"
    
    # Filtrar PendingFileRenameOperations inteligentemente
    $pending = Get-ItemProperty -Path $smPath -Name "PendingFileRenameOperations" -ErrorAction SilentlyContinue
    
    if ($pending.PendingFileRenameOperations) {
        $entries = $pending.PendingFileRenameOperations
        $filtered = @()
        
        for ($i = 0; $i -lt $entries.Count; $i += 2) {
            if ($entries[$i] -notmatch "Autodesk|adsk") {
                $filtered += $entries[$i]
                if ($i + 1 -lt $entries.Count) { $filtered += $entries[$i + 1] }
            }
        }
        
        if ($filtered.Count -lt $entries.Count) {
            Write-Log "  Filtrando PendingFileRenameOperations (removiendo solo Autodesk)" -Level DEBUG
            if (-not $DryRun) {
                if ($filtered.Count -gt 0) {
                    Set-ItemProperty -Path $smPath -Name "PendingFileRenameOperations" -Value $filtered -Type MultiString -Force
                }
                else {
                    Remove-ItemProperty -Path $smPath -Name "PendingFileRenameOperations" -Force -ErrorAction SilentlyContinue
                }
            }
        }
    }
    
    Write-Log "✓ Bucles de reinicio mitigados" -Level SUCCESS
}

# ════════════════════════════════════════════════════════════════════
# MAIN
# ════════════════════════════════════════════════════════════════════

try {
    Clear-Host
    Write-Host "╔═══════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║   AUTODESK-NUKE v4.0 EQUILIBRADA                      ║" -ForegroundColor Cyan
    Write-Host "║   Eliminación segura y auditada de Autodesk            ║" -ForegroundColor Cyan
    Write-Host "╚═══════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    
    Initialize-Logging
    Test-AdminPrivileges
    Request-UserConfirmation
    
    # Ejecutar fases
    $procCount = Stop-AutodeskProcesses
    $svcCount = Stop-AutodeskServices
    Start-Sleep -Seconds 1
    
    $msiCount = Uninstall-MsiPackages
    $regCount = Clear-RegistryKeys
    $userCount = Clear-UserProfiles
    $folderCount = Remove-AutodeskFolders
    $taskCount = Remove-ScheduledTasks
    Fix-RebootLoops
    
    # Reporte
    Write-Host "`n╔═══════════════════════════════════════════════════════╗" -ForegroundColor Green
    Write-Host "║              LIMPIEZA COMPLETADA                      ║" -ForegroundColor Green
    Write-Host "╚═══════════════════════════════════════════════════════╝" -ForegroundColor Green
    
    $report = @"
Procesos detenidos:        $procCount
Servicios detenidos:       $svcCount
Paquetes desinstalados:    $msiCount
Claves de registro:        $regCount
Perfiles de usuario:       $userCount
Carpetas eliminadas:       $folderCount
Tareas programadas:        $taskCount

Archivo de log: $LogPath
"@
    
    Write-Host $report -ForegroundColor Cyan
    $report | Out-File $LogPath -Append -Encoding UTF8
    
    Write-Log "═════════════════════════════════════════════════════════" -Level SUCCESS
    Write-Log "✓ LIMPIEZA COMPLETADA EXITOSAMENTE" -Level SUCCESS
    Write-Log "═════════════════════════════════════════════════════════" -Level SUCCESS
    
    if (-not $DryRun) {
        Write-Host "`n⚠️  Se recomienda REINICIAR el equipo antes de reinstalar Autodesk." -ForegroundColor Yellow
    }
}
catch {
    Write-Log "✗ ERROR CRÍTICO: $($_.Exception.Message)" -Level ERROR
    Write-Log "Stack: $($_.ScriptStackTrace)" -Level DEBUG
    exit 1
}
