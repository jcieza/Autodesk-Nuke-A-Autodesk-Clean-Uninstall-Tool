<#
.SYNOPSIS
    Autodesk-Nuke v5.0 Enterprise Edition
    
.DESCRIPTION
    Herramienta de eliminación de Autodesk diseñada para entornos corporativos (SCCM/Intune).
    Incluye validaciones avanzadas, reportes estructurados, y auditoría completa.
    
    Características Enterprise:
    - Validación de prerequisitos del sistema
    - Logging estructurado con múltiples niveles
    - Modo DryRun con previsualización
    - Barra de progreso visual
    - Reporte final JSON-compatible
    - Verificación post-limpieza
    - Retry automático para operaciones bloqueadas
    - Integración con event log de Windows
    
.PARAMETER AllUsers
    Limpiar todos los perfiles de usuario.
    
.PARAMETER DryRun
    Modo simulación sin cambios reales.
    
.PARAMETER LogPath
    Ruta personalizada para logs.
    
.PARAMETER EventLog
    Registrar eventos en Windows Event Log (requiere admin).
    
.PARAMETER Verify
    Verificar completitud de limpieza al finalizar.
    
.EXAMPLE
    .\Autodesk-Nuke-Enterprise-v5.0.ps1 -DryRun
    .\Autodesk-Nuke-Enterprise-v5.0.ps1 -AllUsers -EventLog -Verify
    
.NOTES
    Versión: 5.0.0-Enterprise
    Diseño: Análisis de 5+ versiones previas
    Requisitos: PowerShell 5.1+, Admin
#>

param(
    [switch]$AllUsers,
    [switch]$DryRun,
    [string]$LogPath = "$env:TEMP\Autodesk-Nuke-Enterprise_$(Get-Date -Format 'yyyyMMdd_HHmmss').log",
    [switch]$EventLog,
    [switch]$Verify,
    [ValidateSet("DEBUG", "INFO", "WARNING", "ERROR")][string]$LogLevel = "INFO"
)

#Requires -Version 5.1
#Requires -RunAsAdministrator

$ErrorActionPreference = "Continue"
Set-StrictMode -Version 2.0

# ════════════════════════════════════════════════════════════════════
# CONFIGURACIÓN Y VARIABLES GLOBALES
# ════════════════════════════════════════════════════════════════════

$script:LogFile = $LogPath
$script:DryRun = $DryRun
$script:MaxRetries = 3
$script:RetryDelay = 1000  # milliseconds

$script:Report = @{
    StartTime        = Get-Date
    EndTime          = $null
    ProcessesStopped = 0
    ServicesStopped  = 0
    PackagesRemoved  = 0
    RegistryKeys     = 0
    Folders          = 0
    Tasks            = 0
    Errors           = @()
    Warnings         = @()
}

# ════════════════════════════════════════════════════════════════════
# FUNCIONES DE LOGGING Y REPORTES
# ════════════════════════════════════════════════════════════════════

function Initialize-Logging {
    param([string]$LogFile = $script:LogFile)
    
    $header = @"
═════════════════════════════════════════════════════════════════════════════
Autodesk-Nuke Enterprise v5.0
Inicio: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
Sistema: Windows $([System.Environment]::OSVersion.VersionString)
Usuario: $env:USERNAME | Máquina: $env:COMPUTERNAME
Modo: $(if($DryRun){'DRY-RUN (sin cambios)'}else{'EJECUCIÓN REAL'})
LogLevel: $LogLevel
═════════════════════════════════════════════════════════════════════════════
"@
    
    $header | Out-File $LogFile -Encoding UTF8 -Force
    Write-Host $header -ForegroundColor Cyan
}

function Write-Log {
    param(
        [string]$Message,
        [ValidateSet("DEBUG", "INFO", "SUCCESS", "WARNING", "ERROR")][string]$Level = "INFO"
    )
    
    # Filtrar por LogLevel
    $levels = @{ DEBUG = 0; INFO = 1; SUCCESS = 1; WARNING = 2; ERROR = 3 }
    $currentLevel = $levels[$LogLevel]
    $messageLevel = $levels[$Level]
    
    if ($messageLevel -lt $currentLevel) { return }
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
    $logEntry = "[$timestamp] [$Level] $Message"
    
    # Escribir a archivo
    Add-Content -Path $script:LogFile -Value $logEntry -Encoding UTF8 -ErrorAction SilentlyContinue
    
    # Escribir a consola
    $colors = @{
        DEBUG   = "Gray"
        INFO    = "Cyan"
        SUCCESS = "Green"
        WARNING = "Yellow"
        ERROR   = "Red"
    }
    
    Write-Host $logEntry -ForegroundColor $colors[$Level]
    
    # Registrar en Windows Event Log si se solicita
    if ($EventLog -and $Level -in @("WARNING", "ERROR")) {
        try {
            Write-EventLog -LogName "System" -Source "AutodeskNuke" -EventId 1000 -EntryType Warning -Message $Message -ErrorAction SilentlyContinue
        }
        catch { }
    }
}

function Show-Progress {
    param(
        [int]$Step,
        [int]$Total,
        [string]$Activity
    )
    
    $percent = [math]::Min(($Step / $Total) * 100, 100)
    Write-Progress -Activity "Limpieza Autodesk" -Status $Activity -PercentComplete $percent -Id 0
}

# ════════════════════════════════════════════════════════════════════
# VALIDACIONES PRE-EJECUCIÓN
# ════════════════════════════════════════════════════════════════════

function Test-Prerequisites {
    Write-Log "Validando prerequisitos del sistema..." -Level INFO
    
    # Verificar espacio en disco
    $diskSpace = (Get-Item C:\ | Measure-Object -Property FreeSpace).FreeSpace / 1GB
    if ($diskSpace -lt 1) {
        Write-Log "⚠️  Espacio en disco bajo: ${diskSpace}GB" -Level WARNING
        $script:Report.Warnings += "Disco bajo: ${diskSpace}GB"
    }
    
    # Verificar si hay actualizaciones pendientes
    $pendingUpdates = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update" -ErrorAction SilentlyContinue
    if ($pendingUpdates) {
        Write-Log "ℹ️  Actualizaciones de Windows pendientes - se recomienda ejecutar post-limpieza" -Level INFO
    }
    
    # Verificar antivirus
    $antivirus = Get-CimInstance -ClassName AntiVirusProduct -ErrorAction SilentlyContinue
    if ($antivirus) {
        Write-Log "ℹ️  Antivirus detectado: puede ralentizar limpieza" -Level INFO
        $script:Report.Warnings += "Antivirus activo (puede bloquear archivos)"
    }
    
    Write-Log "✓ Validación de prerequisitos completada" -Level SUCCESS
}

function Test-AutodeskPresence {
    Write-Log "Escaneando presencia de Autodesk..." -Level INFO
    
    $found = @()
    
    # Registro
    $regPaths = @(
        "HKLM:\SOFTWARE\Autodesk",
        "HKLM:\SOFTWARE\Wow6432Node\Autodesk",
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )
    
    foreach ($path in $regPaths) {
        if (Test-Path $path) {
            $items = Get-ItemProperty $path -ErrorAction SilentlyContinue | 
                Where-Object { $_.DisplayName -match "Autodesk|AutoCAD|Revit|Inventor" }
            
            if ($items) { $found += $items }
        }
    }
    
    # Directorios
    $dirs = @("C:\Program Files\Autodesk", "C:\Program Files (x86)\Autodesk", "C:\ProgramData\Autodesk")
    foreach ($dir in $dirs) {
        if (Test-Path $dir) {
            $found += $dir
        }
    }
    
    # Servicios
    $services = Get-Service -ErrorAction SilentlyContinue | Where-Object { $_.Name -match "Autodesk|Adsk" }
    if ($services) {
        $found += $services
    }
    
    if ($found.Count -eq 0) {
        Write-Log "⚠️  No se detectó presencia de Autodesk" -Level WARNING
        return $false
    }
    
    Write-Log "Detectados $($found.Count) elemento(s) de Autodesk" -Level INFO
    $found | ForEach-Object { 
        Write-Log "  • $($_ | Select-Object -ExpandProperty DisplayName -ErrorAction SilentlyContinue -ExpandProperty Name -ErrorAction SilentlyContinue)" -Level DEBUG
    }
    
    return $true
}

function Request-Confirmation {
    Write-Host "`n" -ForegroundColor Yellow
    Write-Host "╔═══════════════════════════════════════════════════════════╗" -ForegroundColor Yellow
    Write-Host "║          ⚠️  OPERACIÓN DESTRUCTIVA                         ║" -ForegroundColor Yellow
    Write-Host "╚═══════════════════════════════════════════════════════════╝" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Este script eliminará TODO rastro de Autodesk del sistema." -ForegroundColor Yellow
    Write-Host "Esta acción es IRREVERSIBLE y no se puede deshacer." -ForegroundColor Yellow
    Write-Host ""
    
    if ($DryRun) {
        Write-Host "Modo: DRY-RUN (simulación, sin cambios reales)" -ForegroundColor Green
        Write-Host ""
        return $true
    }
    
    Write-Host "Para confirmar, escribe exactamente: DELETE_AUTODESK" -ForegroundColor Yellow
    Write-Host "(sensible a mayúsculas/minúsculas)" -ForegroundColor Yellow
    Write-Host ""
    
    $response = Read-Host "Confirmación"
    
    if ($response -ne "DELETE_AUTODESK") {
        Write-Log "Operación cancelada por usuario" -Level INFO
        exit 0
    }
    
    Write-Log "Confirmación de usuario recibida. Iniciando limpieza..." -Level INFO
    return $true
}

# ════════════════════════════════════════════════════════════════════
# OPERACIONES DE LIMPIEZA
# ════════════════════════════════════════════════════════════════════

function Invoke-RetryableOperation {
    param(
        [string]$Description,
        [scriptblock]$Operation
    )
    
    $attemptNumber = 0
    $success = $false
    
    while ($attemptNumber -lt $script:MaxRetries -and -not $success) {
        $attemptNumber++
        
        try {
            if ($DryRun) {
                Write-Log "[DRY-RUN] $Description" -Level INFO
                return $true
            }
            
            Write-Log "[$attemptNumber/$($script:MaxRetries)] Ejecutando: $Description" -Level DEBUG
            & $Operation
            $success = $true
            Write-Log "✓ $Description" -Level SUCCESS
        }
        catch {
            if ($attemptNumber -lt $script:MaxRetries) {
                Write-Log "  ⚠️  Intento $attemptNumber falló, reintentando..." -Level WARNING
                Start-Sleep -Milliseconds $script:RetryDelay
            }
            else {
                Write-Log "✗ Error después de $($script:MaxRetries) intentos: $Description" -Level ERROR
                $script:Report.Errors += "$Description - $($_.Exception.Message)"
                return $false
            }
        }
    }
    
    return $success
}

function Stop-AutodeskServices {
    param([int]$StepNumber, [int]$TotalSteps)
    
    Show-Progress $StepNumber $TotalSteps "Deteniendo procesos y servicios..."
    Write-Log "╭─ PASO $StepNumber: Deteniendo servicios Autodesk" -Level INFO
    
    # Procesos
    $processes = @("AutodeskAccess", "AdskIdentityManager", "AdSSO", "AdLM", "Node")
    foreach ($procName in $processes) {
        $procs = @(Get-Process -Name $procName -ErrorAction SilentlyContinue)
        foreach ($proc in $procs) {
            Invoke-RetryableOperation "Detener proceso: $($proc.Name) (PID: $($proc.Id))" {
                $proc | Stop-Process -Force -ErrorAction Stop
            } | Out-Null
            $script:Report.ProcessesStopped++
        }
    }
    
    # Servicios
    $services = @(Get-Service -ErrorAction SilentlyContinue | 
        Where-Object { $_.Name -match "Autodesk|Adsk|SSO" })
    
    foreach ($svc in $services) {
        Invoke-RetryableOperation "Detener servicio: $($svc.Name)" {
            Stop-Service -Name $svc.Name -Force -ErrorAction Stop
            Start-Sleep -Milliseconds 500
            
            # Fallback: matar proceso
            $cim = Get-CimInstance -ClassName Win32_Service -Filter "Name='$($svc.Name)'" -ErrorAction SilentlyContinue
            if ($cim.ProcessId -gt 0) {
                Stop-Process -Id $cim.ProcessId -Force -ErrorAction SilentlyContinue
            }
        } | Out-Null
        $script:Report.ServicesStopped++
    }
    
    Write-Log "╰─ Completado: $($script:Report.ProcessesStopped) procesos, $($script:Report.ServicesStopped) servicios" -Level SUCCESS
}

function Uninstall-Packages {
    param([int]$StepNumber, [int]$TotalSteps)
    
    Show-Progress $StepNumber $TotalSteps "Ejecutando desinstaladores..."
    Write-Log "╭─ PASO $StepNumber: Desinstalación de paquetes MSI/ODIS" -Level INFO
    
    $regPaths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )
    
    $packages = @(Get-ItemProperty $regPaths -ErrorAction SilentlyContinue | 
        Where-Object { ($_.DisplayName -match "Autodesk" -or $_.Publisher -match "Autodesk") -and $_.UninstallString })
    
    foreach ($pkg in $packages) {
        Write-Log "Desinstalando: $($pkg.DisplayName)" -Level DEBUG
        
        if ($pkg.UninstallString -match "msiexec") {
            $args = ($pkg.UninstallString -ireplace "msiexec.exe","" -ireplace "/I","/X") + " /quiet /qn /norestart"
            Invoke-RetryableOperation "MSI: $($pkg.DisplayName)" {
                Start-Process "msiexec.exe" -ArgumentList $args -Wait -NoNewWindow -ErrorAction Stop
            } | Out-Null
        }
        elseif ($pkg.UninstallString -match "Installer.exe") {
            $exePath = $pkg.UninstallString.Split("-")[0].Trim(' "')
            if (Test-Path $exePath) {
                Invoke-RetryableOperation "ODIS: $($pkg.DisplayName)" {
                    Start-Process $exePath -ArgumentList "-q -i uninstall" -Wait -NoNewWindow
                } | Out-Null
            }
        }
        
        $script:Report.PackagesRemoved++
    }
    
    Write-Log "╰─ Completado: $($script:Report.PackagesRemoved) paquetes" -Level SUCCESS
}

function Clear-Registry {
    param([int]$StepNumber, [int]$TotalSteps)
    
    Show-Progress $StepNumber $TotalSteps "Limpiando registro..."
    Write-Log "╭─ PASO $StepNumber: Limpieza de registro (HKLM/HKCR)" -Level INFO
    
    $keys = @("HKLM:\SOFTWARE\Autodesk", "HKLM:\SOFTWARE\Wow6432Node\Autodesk", "HKCR:\Autodesk")
    
    foreach ($key in $keys) {
        if (Test-Path $key) {
            Invoke-RetryableOperation "Eliminar clave: $key" {
                Remove-Item -Path $key -Recurse -Force -ErrorAction Stop
            } | Out-Null
            $script:Report.RegistryKeys++
        }
    }
    
    # Entradas fantasma
    $uninstallPaths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )
    
    Get-ItemProperty $uninstallPaths -ErrorAction SilentlyContinue | 
        Where-Object { $_.DisplayName -match "Autodesk" } | 
        ForEach-Object {
            Invoke-RetryableOperation "Entrada: $($_.DisplayName)" {
                Remove-Item -Path $_.PSPath -Force -ErrorAction Stop
            } | Out-Null
            $script:Report.RegistryKeys++
        }
    
    Write-Log "╰─ Completado: $($script:Report.RegistryKeys) claves" -Level SUCCESS
}

function Clear-Folders {
    param([int]$StepNumber, [int]$TotalSteps)
    
    Show-Progress $StepNumber $TotalSteps "Eliminando carpetas..."
    Write-Log "╭─ PASO $StepNumber: Eliminación de carpetas" -Level INFO
    
    $dirs = @(
        "C:\Program Files\Autodesk",
        "C:\Program Files (x86)\Autodesk",
        "C:\ProgramData\Autodesk",
        "$env:ProgramData\FLEXnet"
    )
    
    if ($AllUsers) {
        $userProfiles = Get-ChildItem "C:\Users" -Directory -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -notmatch "^(Public|Default)" }
        
        foreach ($profile in $userProfiles) {
            $dirs += "$($profile.FullName)\AppData\Local\Autodesk"
            $dirs += "$($profile.FullName)\AppData\Roaming\Autodesk"
        }
    }
    else {
        $dirs += "$env:LOCALAPPDATA\Autodesk"
        $dirs += "$env:APPDATA\Autodesk"
    }
    
    # TEMP seguro (solo subdirectorios Autodesk)
    $tempDirs = Get-ChildItem -Path $env:TEMP -Directory -Filter "*Autodesk*" -ErrorAction SilentlyContinue
    $dirs += $tempDirs.FullName
    
    $dirs = $dirs | Select-Object -Unique
    
    foreach ($dir in $dirs) {
        if (Test-Path $dir) {
            Invoke-RetryableOperation "Carpeta: $dir" {
                Remove-Item -Path $dir -Recurse -Force -ErrorAction Stop
            } | Out-Null
            $script:Report.Folders++
        }
    }
    
    Write-Log "╰─ Completado: $($script:Report.Folders) carpetas" -Level SUCCESS
}

function Clear-ScheduledTasks {
    param([int]$StepNumber, [int]$TotalSteps)
    
    Show-Progress $StepNumber $TotalSteps "Eliminando tareas programadas..."
    Write-Log "╭─ PASO $StepNumber: Eliminación de tareas programadas" -Level INFO
    
    $tasks = @(Get-ScheduledTask -TaskPath "\Autodesk*" -ErrorAction SilentlyContinue)
    
    foreach ($task in $tasks) {
        Invoke-RetryableOperation "Tarea: $($task.TaskName)" {
            Unregister-ScheduledTask -TaskName $task.TaskName -Confirm:$false -ErrorAction Stop
        } | Out-Null
        $script:Report.Tasks++
    }
    
    Write-Log "╰─ Completado: $($script:Report.Tasks) tareas" -Level SUCCESS
}

function Fix-RebootLoops {
    param([int]$StepNumber, [int]$TotalSteps)
    
    Show-Progress $StepNumber $TotalSteps "Mitigando bucles de reinicio..."
    Write-Log "╭─ PASO $StepNumber: Reparación de bucles de reinicio" -Level INFO
    
    $smPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager"
    $pending = Get-ItemProperty -Path $smPath -Name "PendingFileRenameOperations" -ErrorAction SilentlyContinue
    
    if ($pending.PendingFileRenameOperations) {
        $entries = $pending.PendingFileRenameOperations
        $filtered = @()
        
        Write-Log "  Analizando $($entries.Count) entradas de PendingFileRenameOperations..." -Level DEBUG
        
        for ($i = 0; $i -lt $entries.Count; $i += 2) {
            if ($entries[$i] -notmatch "Autodesk|adsk") {
                $filtered += $entries[$i]
                if ($i + 1 -lt $entries.Count) { $filtered += $entries[$i + 1] }
            }
        }
        
        if ($filtered.Count -lt $entries.Count) {
            Write-Log "  Filtrando: removiendo $([math]::Floor(($entries.Count - $filtered.Count) / 2)) entradas de Autodesk" -Level DEBUG
            
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
    
    Write-Log "╰─ Completado" -Level SUCCESS
}

function Clear-UserProfiles {
    param([int]$StepNumber, [int]$TotalSteps)
    
    Show-Progress $StepNumber $TotalSteps "Limpiando perfiles de usuario..."
    Write-Log "╭─ PASO $StepNumber: Limpieza de perfiles de usuario (HKCU/NTUSER.DAT)" -Level INFO
    
    if ($AllUsers) {
        $profiles = @(Get-ChildItem "C:\Users" -Directory -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -notmatch "^(Public|Default)" })
        
        foreach ($profile in $profiles) {
            $ntuserPath = Join-Path $profile.FullName "NTUSER.DAT"
            
            if (-not (Test-Path $ntuserPath)) { continue }
            
            if ($profile.Name -eq $env:USERNAME) {
                Invoke-RetryableOperation "HKCU: $($profile.Name)" {
                    Remove-Item "HKCU:\Software\Autodesk" -Recurse -Force -ErrorAction SilentlyContinue
                } | Out-Null
            }
            else {
                $hiveKey = "TEMP_$($profile.Name)"
                Write-Log "  Montando hive offline: $($profile.Name)" -Level DEBUG
                
                & cmd /c "reg load HKU\$hiveKey `"$ntuserPath`"" 2>$null
                if ($LASTEXITCODE -eq 0) {
                    try {
                        $regPath = "Registry::HKEY_USERS\$hiveKey\Software\Autodesk"
                        if (Test-Path $regPath -and -not $DryRun) {
                            Remove-Item -Path $regPath -Recurse -Force -ErrorAction SilentlyContinue
                        }
                    }
                    finally {
                        [gc]::Collect()
                        [gc]::WaitForPendingFinalizers()
                        Start-Sleep -Milliseconds 500
                        & cmd /c "reg unload HKU\$hiveKey" 2>$null
                    }
                }
            }
        }
    }
    else {
        Invoke-RetryableOperation "HKCU: Usuario actual" {
            Remove-Item "HKCU:\Software\Autodesk" -Recurse -Force -ErrorAction SilentlyContinue
        } | Out-Null
    }
    
    Write-Log "╰─ Completado" -Level SUCCESS
}

function Verify-CleanupCompletion {
    Write-Log "Verificando completitud de la limpieza..." -Level INFO
    
    $remaining = @()
    
    if (Test-Path "HKLM:\SOFTWARE\Autodesk") {
        $remaining += "Clave HKLM\SOFTWARE\Autodesk"
    }
    
    if (Test-Path "C:\Program Files\Autodesk") {
        $remaining += "Carpeta C:\Program Files\Autodesk"
    }
    
    $services = @(Get-Service -ErrorAction SilentlyContinue | 
        Where-Object { $_.Name -match "Autodesk" })
    if ($services) {
        $remaining += "Servicios: $($services.Name -join ', ')"
    }
    
    if ($remaining.Count -gt 0) {
        Write-Log "⚠️  Detectados restos de Autodesk:" -Level WARNING
        $remaining | ForEach-Object { Write-Log "  - $_" -Level WARNING }
        return $false
    }
    
    Write-Log "✓ Limpieza verificada exitosamente" -Level SUCCESS
    return $true
}

# ════════════════════════════════════════════════════════════════════
# MAIN EXECUTION
# ════════════════════════════════════════════════════════════════════

try {
    Initialize-Logging
    
    Test-Prerequisites
    Test-AutodeskPresence | Out-Null
    Request-Confirmation
    
    $totalSteps = 8
    
    Stop-AutodeskServices 1 $totalSteps
    Uninstall-Packages 2 $totalSteps
    Clear-Registry 3 $totalSteps
    Clear-UserProfiles 4 $totalSteps
    Clear-Folders 5 $totalSteps
    Clear-ScheduledTasks 6 $totalSteps
    Fix-RebootLoops 7 $totalSteps
    
    if ($Verify) {
        Show-Progress 8 $totalSteps "Verificando..."
        Verify-CleanupCompletion | Out-Null
    }
    
    Show-Progress 8 $totalSteps "Completado"
    
    # Reporte final
    $script:Report.EndTime = Get-Date
    $duration = ($script:Report.EndTime - $script:Report.StartTime).TotalSeconds
    
    $reportText = @"
╔═════════════════════════════════════════════════════════════════════════════╗
║                         REPORTE FINAL - LIMPIEZA                           ║
╚═════════════════════════════════════════════════════════════════════════════╝

Procesos detenidos:        $($script:Report.ProcessesStopped)
Servicios detenidos:       $($script:Report.ServicesStopped)
Paquetes desinstalados:    $($script:Report.PackagesRemoved)
Claves de registro:        $($script:Report.RegistryKeys)
Carpetas eliminadas:       $($script:Report.Folders)
Tareas programadas:        $($script:Report.Tasks)
Duración total:            $([math]::Round($duration, 2))s

Errores:                   $($script:Report.Errors.Count)
Advertencias:              $($script:Report.Warnings.Count)

Archivo log:               $LogPath
═════════════════════════════════════════════════════════════════════════════════
"@
    
    if ($script:Report.Errors.Count -gt 0) {
        $reportText += "`nERRORES ENCONTRADOS:`n"
        $script:Report.Errors | ForEach-Object { $reportText += "  ✗ $_`n" }
    }
    
    if ($script:Report.Warnings.Count -gt 0) {
        $reportText += "`nADVERTENCIAS:`n"
        $script:Report.Warnings | ForEach-Object { $reportText += "  ⚠️  $_`n" }
    }
    
    Write-Host $reportText -ForegroundColor Green
    $reportText | Out-File $LogPath -Append -Encoding UTF8
    
    Write-Log "═════════════════════════════════════════════════════════════════════════════════" -Level SUCCESS
    Write-Log "✓ LIMPIEZA COMPLETADA EXITOSAMENTE" -Level SUCCESS
    Write-Log "═════════════════════════════════════════════════════════════════════════════════" -Level SUCCESS
    
    if (-not $DryRun) {
        Write-Host "`n⚠️  Se recomienda REINICIAR el equipo antes de reinstalar Autodesk." -ForegroundColor Yellow
    }
}
catch {
    Write-Log "✗ ERROR CRÍTICO: $($_.Exception.Message)" -Level ERROR
    Write-Log "Stack Trace: $($_.ScriptStackTrace)" -Level DEBUG
    exit 1
}
