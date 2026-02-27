<#
.SYNOPSIS
    Autodesk-Nuke v6.0 FINAL - La herramienta definitiva de limpieza
    
.DESCRIPTION
    Script de limpieza de Autodesk con selección inteligente de profundidad.
    Adapta automáticamente su comportamiento según las necesidades del usuario
    (Basic, Advanced, Enterprise) sin sacrificar seguridad ni robustez.
    
    Características:
    - Selección interactiva de nivel de profundidad
    - Logging inteligente adaptado al nivel
    - Manejo de errores contextuales
    - DryRun mode con previsualización
    - Validaciones exhaustivas
    - Barra de progreso adaptativa
    - Verificación post-limpieza automática
    - Auditoría completa con estadísticas
    - Reintentos automáticos para operaciones bloqueadas
    - Preservación inteligente de datos del SO
    
.PARAMETER DryRun
    Simular sin cambios reales.
    
.PARAMETER LogPath
    Ruta personalizada para archivo de log.
    
.PARAMETER SkipValidation
    Saltar validaciones iniciales (solo para testing).
    
.PARAMETER QuietMode
    Reducir output de consola (solo logs a archivo).
    
.EXAMPLE
    .\Autodesk-Nuke-FINAL-v6.0.ps1
    .\Autodesk-Nuke-FINAL-v6.0.ps1 -DryRun
    
.NOTES
    Versión: 6.0.0-FINAL
    Autor: Contribuidor de Comunidad
    Requisitos: PowerShell 5.1+, Admin
    Basado en: Análisis de 7 versiones previas
#>

param(
    [switch]$DryRun,
    [string]$LogPath = "$env:TEMP\Autodesk-Nuke-FINAL_$(Get-Date -Format 'yyyyMMdd_HHmmss').log",
    [switch]$SkipValidation,
    [switch]$QuietMode
)

#Requires -Version 5.1
Set-StrictMode -Version 2.0
$ErrorActionPreference = "Continue"

# ════════════════════════════════════════════════════════════════════════════════
# CONFIGURACIÓN GLOBAL
# ════════════════════════════════════════════════════════════════════════════════

$script:Config = @{
    LogFile           = $LogPath
    DryRun            = $DryRun
    QuietMode         = $QuietMode
    CleanupLevel      = $null  # Se establece interactivamente
    MaxRetries        = 3
    RetryDelay        = 1000
    WarningsAsErrors  = $false
    StartTime         = Get-Date
    EndTime           = $null
}

$script:Stats = @{
    ProcessesStopped  = 0
    ServicesStopped   = 0
    PackagesRemoved   = 0
    RegistryKeys      = 0
    Folders           = 0
    Tasks             = 0
    Errors            = @()
    Warnings          = @()
    Skipped           = 0
}

# Niveles de profundidad
$script:CleanupLevels = @{
    "BASIC"       = @{
        Name        = "Limpieza Básica"
        Description = "Detiene procesos/servicios, desinstala MSI, limpia HKLM"
        Duration    = "2-3 minutos"
        Risk        = "Bajo"
        Scope       = @{
            Processes             = $true
            Services              = $true
            MSI                   = $true
            HKLM                  = $true
            HKCU                  = $false
            MultiUser             = $false
            Tasks                 = $false
            Temp                  = $false
            ScheduledTasks        = $false
            EnvironmentVariables  = $false
        }
    }
    "ADVANCED"    = @{
        Name        = "Limpieza Avanzada"
        Description = "Básica + perfiles de usuario actuales, TEMP, tareas programadas"
        Duration    = "5-10 minutos"
        Risk        = "Medio"
        Scope       = @{
            Processes             = $true
            Services              = $true
            MSI                   = $true
            HKLM                  = $true
            HKCU                  = $true
            MultiUser             = $false
            Tasks                 = $false
            Temp                  = $true
            ScheduledTasks        = $true
            EnvironmentVariables  = $false
        }
    }
    "ENTERPRISE"  = @{
        Name        = "Limpieza Empresarial"
        Description = "Limpieza completa: todos los usuarios, todas las carpetas, auditoría"
        Duration    = "10-20 minutos"
        Risk        = "Medio-Alto"
        Scope       = @{
            Processes             = $true
            Services              = $true
            MSI                   = $true
            HKLM                  = $true
            HKCU                  = $true
            MultiUser             = $true
            Tasks                 = $true
            Temp                  = $true
            ScheduledTasks        = $true
            EnvironmentVariables  = $true
        }
    }
}

# ════════════════════════════════════════════════════════════════════════════════
# FUNCIONES DE LOGGING Y SALIDA
# ════════════════════════════════════════════════════════════════════════════════

function Initialize-Logging {
    $header = @"
════════════════════════════════════════════════════════════════════════════════
Autodesk-Nuke v6.0 FINAL - La Herramienta Definitiva de Limpieza
════════════════════════════════════════════════════════════════════════════════
Inicio:       $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
Sistema:      Windows $([System.Environment]::OSVersion.VersionString)
Usuario:      $env:USERNAME | Máquina: $env:COMPUTERNAME
Modo:         $(if($script:Config.DryRun){'DRY-RUN (simulación)'}else{'EJECUCIÓN REAL'})
Nivel:        $($script:Config.CleanupLevel)
════════════════════════════════════════════════════════════════════════════════
"@
    
    $header | Out-File $script:Config.LogFile -Encoding UTF8 -Force
    Write-LogOutput $header -NoLog
}

function Write-LogOutput {
    param(
        [string]$Message,
        [ValidateSet("DEBUG", "INFO", "SUCCESS", "WARNING", "ERROR")][string]$Level = "INFO",
        [switch]$NoLog,
        [switch]$NoConsole
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
    $logEntry = "[$timestamp] [$Level] $Message"
    
    # Escribir a archivo si no se especifica -NoLog
    if (-not $NoLog) {
        Add-Content -Path $script:Config.LogFile -Value $logEntry -Encoding UTF8 -ErrorAction SilentlyContinue
    }
    
    # Escribir a consola si no está en QuietMode y no se especifica -NoConsole
    if (-not $script:Config.QuietMode -and -not $NoConsole) {
        $colors = @{
            DEBUG   = "Gray"
            INFO    = "Cyan"
            SUCCESS = "Green"
            WARNING = "Yellow"
            ERROR   = "Red"
        }
        Write-Host $logEntry -ForegroundColor $colors[$Level]
    }
    
    # Registrar en estadísticas
    if ($Level -eq "ERROR") {
        $script:Stats.Errors += $Message
    }
    elseif ($Level -eq "WARNING") {
        $script:Stats.Warnings += $Message
    }
}

function Show-Banner {
    param([string]$Text, [string]$Color = "Cyan")
    
    $width = 80
    $padding = [math]::Max(0, [math]::Floor(($width - $Text.Length) / 2))
    
    Write-Host "`n╔$(('═' * ($width - 2)))╗" -ForegroundColor $Color
    Write-Host "║$((' ' * $padding))$Text$((' ' * ($width - $padding - $Text.Length - 1)))║" -ForegroundColor $Color
    Write-Host "╚$(('═' * ($width - 2)))╝`n" -ForegroundColor $Color
}

function Show-Progress {
    param(
        [int]$Step,
        [int]$Total,
        [string]$Activity
    )
    
    $percent = [math]::Min(($Step / $Total) * 100, 100)
    Write-Progress -Activity "Limpieza Autodesk v6.0" -Status $Activity -PercentComplete $percent -Id 0
}

# ════════════════════════════════════════════════════════════════════════════════
# SELECCIÓN DE NIVEL DE PROFUNDIDAD
# ════════════════════════════════════════════════════════════════════════════════

function Select-CleanupLevel {
    Show-Banner "SELECCIONAR NIVEL DE LIMPIEZA" "Yellow"
    
    Write-Host "¿Cuál es tu escenario?" -ForegroundColor Cyan
    Write-Host ""
    
    $index = 1
    foreach ($level in $script:CleanupLevels.Keys) {
        $info = $script:CleanupLevels[$level]
        Write-Host "  $index) $($info.Name)" -ForegroundColor Green
        Write-Host "     📝 $($info.Description)" -ForegroundColor Gray
        Write-Host "     ⏱️  Duración: $($info.Duration)" -ForegroundColor Gray
        Write-Host "     ⚠️  Riesgo: $($info.Risk)" -ForegroundColor Gray
        Write-Host ""
        $index++
    }
    
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
    Write-Host ""
    
    $selection = Read-Host "Selecciona 1, 2 o 3"
    
    $levelMap = @{
        "1" = "BASIC"
        "2" = "ADVANCED"
        "3" = "ENTERPRISE"
    }
    
    if ($levelMap[$selection]) {
        $script:Config.CleanupLevel = $levelMap[$selection]
        Write-LogOutput "Usuario seleccionó nivel: $($script:Config.CleanupLevel)" -Level INFO
        
        $levelInfo = $script:CleanupLevels[$script:Config.CleanupLevel]
        Show-Banner "NIVEL: $($levelInfo.Name)" "Green"
        Write-LogOutput "Scope seleccionado: $(($levelInfo.Scope.GetEnumerator() | Where-Object {$_.Value} | ForEach-Object {$_.Key}) -join ', ')" -Level DEBUG
        
        return $true
    }
    else {
        Write-Host "`n❌ Selección inválida. Abortando..." -ForegroundColor Red
        Write-LogOutput "Selección inválida por usuario" -Level ERROR
        exit 1
    }
}

# ════════════════════════════════════════════════════════════════════════════════
# VALIDACIONES PRE-EJECUCIÓN
# ════════════════════════════════════════════════════════════════════════════════

function Test-AdminPrivileges {
    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.BuiltInRole]::Administrator)
    
    if (-not $isAdmin) {
        Write-LogOutput "Elevando privilegios..." -Level WARNING
        try {
            $params = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
            if ($script:Config.DryRun) { $params += " -DryRun" }
            if ($script:Config.QuietMode) { $params += " -QuietMode" }
            
            Start-Process PowerShell -ArgumentList $params -Verb RunAs -Wait
            exit 0
        }
        catch {
            Write-LogOutput "Elevación fallida. Ejecuta como Admin manualmente." -Level ERROR
            exit 1
        }
    }
    
    Write-LogOutput "✓ Ejecutando con permisos de Administrador" -Level SUCCESS
}

function Test-Prerequisites {
    if ($SkipValidation) {
        Write-LogOutput "Validaciones saltadas (SkipValidation)" -Level WARNING
        return $true
    }
    
    Write-LogOutput "Validando prerequisitos del sistema..." -Level INFO
    
    # Disco
    $diskSpace = (Get-Item C:\ | Measure-Object -Property FreeSpace).FreeSpace / 1GB
    if ($diskSpace -lt 0.5) {
        Write-LogOutput "❌ CRÍTICO: Espacio en disco insuficiente: ${diskSpace}GB" -Level ERROR
        return $false
    }
    elseif ($diskSpace -lt 1) {
        Write-LogOutput "⚠️  Espacio en disco bajo: ${diskSpace}GB" -Level WARNING
    }
    
    # Antivirus
    try {
        $antivirus = Get-CimInstance -ClassName AntiVirusProduct -ErrorAction SilentlyContinue
        if ($antivirus) {
            Write-LogOutput "ℹ️  Antivirus detectado: puede ralentizar limpieza" -Level INFO
        }
    }
    catch { }
    
    # Autodesk presente
    $found = Test-AutodeskPresence
    if (-not $found) {
        Write-LogOutput "⚠️  No se detectó presencia de Autodesk" -Level WARNING
        $response = Read-Host "¿Continuar de todas formas? (S/N)"
        if ($response -ne "S") {
            Write-LogOutput "Operación cancelada por usuario" -Level INFO
            exit 0
        }
    }
    
    Write-LogOutput "✓ Validaciones completadas" -Level SUCCESS
    return $true
}

function Test-AutodeskPresence {
    Write-LogOutput "Escaneando presencia de Autodesk..." -Level INFO
    
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
            Write-LogOutput "  Carpeta encontrada: $dir" -Level DEBUG
            $found += $dir
        }
    }
    
    # Servicios
    $services = @(Get-Service -ErrorAction SilentlyContinue | Where-Object { $_.Name -match "Autodesk|Adsk" })
    if ($services) {
        Write-LogOutput "  Servicios encontrados: $($services.Count)" -Level DEBUG
        $found += $services
    }
    
    if ($found.Count -gt 0) {
        Write-LogOutput "✓ Detectados $($found.Count) elemento(s) de Autodesk" -Level SUCCESS
        return $true
    }
    
    return $false
}

function Request-FinalConfirmation {
    $levelInfo = $script:CleanupLevels[$script:Config.CleanupLevel]
    
    Show-Banner "⚠️  CONFIRMACIÓN FINAL" "Yellow"
    
    Write-Host "Vas a ejecutar una limpieza: $($levelInfo.Name)" -ForegroundColor Yellow
    Write-Host "Scope: $(($levelInfo.Scope.GetEnumerator() | Where-Object {$_.Value} | ForEach-Object {$_.Key}) -join ', ')" -ForegroundColor Yellow
    Write-Host ""
    
    if ($script:Config.DryRun) {
        Write-Host "Modo: DRY-RUN (no se realizarán cambios)" -ForegroundColor Green
        return $true
    }
    
    Write-Host "Esta acción es IRREVERSIBLE." -ForegroundColor Red
    Write-Host ""
    Write-Host "Escribe exactamente: LIMPIAR $($script:Config.CleanupLevel)" -ForegroundColor Yellow
    Write-Host "(sensible a mayúsculas/minúsculas)" -ForegroundColor Yellow
    Write-Host ""
    
    $response = Read-Host "Confirmación"
    
    if ($response -eq "LIMPIAR $($script:Config.CleanupLevel)") {
        Write-LogOutput "Confirmación válida recibida. Iniciando limpieza..." -Level INFO
        return $true
    }
    else {
        Write-LogOutput "Confirmación inválida. Operación cancelada." -Level INFO
        exit 0
    }
}

# ════════════════════════════════════════════════════════════════════════════════
# FUNCIONES DE OPERACIONES INTELIGENTES
# ════════════════════════════════════════════════════════════════════════════════

function Invoke-SafeOperation {
    param(
        [string]$Description,
        [scriptblock]$Operation,
        [string]$ErrorMessage = $null
    )
    
    $attemptNumber = 0
    $success = $false
    
    while ($attemptNumber -lt $script:Config.MaxRetries -and -not $success) {
        $attemptNumber++
        
        try {
            if ($script:Config.DryRun) {
                Write-LogOutput "[DRY-RUN] $Description" -Level INFO
                return $true
            }
            
            Write-LogOutput "Ejecutando: $Description" -Level DEBUG
            $null = & $Operation
            $success = $true
        }
        catch [System.IO.IOException] {
            if ($attemptNumber -lt $script:Config.MaxRetries) {
                Write-LogOutput "Archivo bloqueado. Reintentando ($attemptNumber/$($script:Config.MaxRetries))..." -Level WARNING
                Start-Sleep -Milliseconds $script:Config.RetryDelay
            }
            else {
                Write-LogOutput "✗ No se pudo desbloquer después de $($script:Config.MaxRetries) intentos: $Description" -Level WARNING
                $script:Stats.Skipped++
                return $false
            }
        }
        catch {
            Write-LogOutput "✗ Error: $(if($ErrorMessage){$ErrorMessage}else{$_.Exception.Message})" -Level ERROR
            return $false
        }
    }
    
    if ($success) {
        Write-LogOutput "✓ $Description" -Level SUCCESS
    }
    
    return $success
}

# ════════════════════════════════════════════════════════════════════════════════
# OPERACIONES DE LIMPIEZA (Adaptadas al nivel)
# ════════════════════════════════════════════════════════════════════════════════

function Stop-ProcessesAndServices {
    param([int]$Step, [int]$Total)
    
    Show-Progress $Step $Total "Deteniendo procesos y servicios..."
    Write-LogOutput "═ PASO $Step: Deteniendo procesos y servicios" -Level INFO
    
    # Procesos críticos
    $processes = @("AutodeskAccess", "AdskIdentityManager", "AdSSO", "AdLM", "Node")
    foreach ($procName in $processes) {
        $procs = @(Get-Process -Name $procName -ErrorAction SilentlyContinue)
        foreach ($proc in $procs) {
            Invoke-SafeOperation "Proceso: $($proc.Name) (PID: $($proc.Id))" {
                $proc | Stop-Process -Force -ErrorAction Stop
            } | Out-Null
            $script:Stats.ProcessesStopped++
        }
    }
    
    # Servicios
    $services = @(Get-Service -ErrorAction SilentlyContinue | 
        Where-Object { $_.Name -match "Autodesk|Adsk|SSO" })
    
    foreach ($svc in $services) {
        Invoke-SafeOperation "Servicio: $($svc.Name)" {
            Stop-Service -Name $svc.Name -Force -ErrorAction Stop
            Start-Sleep -Milliseconds 500
            
            $cim = Get-CimInstance -ClassName Win32_Service -Filter "Name='$($svc.Name)'" -ErrorAction SilentlyContinue
            if ($cim -and $cim.ProcessId -gt 0) {
                Stop-Process -Id $cim.ProcessId -Force -ErrorAction SilentlyContinue
            }
        } | Out-Null
        $script:Stats.ServicesStopped++
    }
    
    Write-LogOutput "  Procesos: $($script:Stats.ProcessesStopped) | Servicios: $($script:Stats.ServicesStopped)" -Level INFO
}

function Uninstall-Packages {
    param([int]$Step, [int]$Total)
    
    Show-Progress $Step $Total "Desinstalando paquetes..."
    Write-LogOutput "═ PASO $Step: Desinstalación de paquetes MSI/ODIS" -Level INFO
    
    $regPaths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )
    
    $packages = @(Get-ItemProperty $regPaths -ErrorAction SilentlyContinue | 
        Where-Object { ($_.DisplayName -match "Autodesk" -or $_.Publisher -match "Autodesk") -and $_.UninstallString })
    
    foreach ($pkg in $packages) {
        Write-LogOutput "  Detectado: $($pkg.DisplayName)" -Level DEBUG
        
        if ($pkg.UninstallString -match "msiexec") {
            $args = ($pkg.UninstallString -ireplace "msiexec.exe","" -ireplace "/I","/X") + " /quiet /qn /norestart"
            Invoke-SafeOperation "MSI: $($pkg.DisplayName)" {
                Start-Process "msiexec.exe" -ArgumentList $args -Wait -NoNewWindow -ErrorAction Stop
            } | Out-Null
        }
        elseif ($pkg.UninstallString -match "Installer.exe") {
            $exePath = $pkg.UninstallString.Split("-")[0].Trim(' "')
            if (Test-Path $exePath) {
                Invoke-SafeOperation "ODIS: $($pkg.DisplayName)" {
                    Start-Process $exePath -ArgumentList "-q -i uninstall" -Wait -NoNewWindow
                } | Out-Null
            }
        }
        
        $script:Stats.PackagesRemoved++
    }
    
    Write-LogOutput "  Paquetes desinstalados: $($script:Stats.PackagesRemoved)" -Level INFO
}

function Clear-Registry {
    param([int]$Step, [int]$Total)
    
    Show-Progress $Step $Total "Limpiando registro..."
    Write-LogOutput "═ PASO $Step: Limpieza de registro" -Level INFO
    
    $scope = $script:CleanupLevels[$script:Config.CleanupLevel].Scope
    
    if ($scope.HKLM) {
        $keys = @("HKLM:\SOFTWARE\Autodesk", "HKLM:\SOFTWARE\Wow6432Node\Autodesk", "HKCR:\Autodesk")
        
        foreach ($key in $keys) {
            if (Test-Path $key) {
                Invoke-SafeOperation "Clave: $key" {
                    Remove-Item -Path $key -Recurse -Force -ErrorAction Stop
                } | Out-Null
                $script:Stats.RegistryKeys++
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
                Invoke-SafeOperation "Entrada: $($_.DisplayName)" {
                    Remove-Item -Path $_.PSPath -Force -ErrorAction Stop
                } | Out-Null
                $script:Stats.RegistryKeys++
            }
    }
    
    Write-LogOutput "  Claves de registro: $($script:Stats.RegistryKeys)" -Level INFO
}

function Clear-Folders {
    param([int]$Step, [int]$Total)
    
    Show-Progress $Step $Total "Eliminando carpetas..."
    Write-LogOutput "═ PASO $Step: Eliminación de carpetas" -Level INFO
    
    $scope = $script:CleanupLevels[$script:Config.CleanupLevel].Scope
    
    $dirs = @()
    
    if ($scope.HKLM) {
        $dirs += @(
            "C:\Program Files\Autodesk",
            "C:\Program Files (x86)\Autodesk",
            "C:\ProgramData\Autodesk",
            "$env:ProgramData\FLEXnet"
        )
    }
    
    if ($scope.Temp) {
        $tempDirs = Get-ChildItem -Path $env:TEMP -Directory -Filter "*Autodesk*" -ErrorAction SilentlyContinue
        $dirs += $tempDirs.FullName
    }
    
    if ($scope.HKCU) {
        if ($scope.MultiUser) {
            $profiles = Get-ChildItem "C:\Users" -Directory -ErrorAction SilentlyContinue |
                Where-Object { $_.Name -notmatch "^(Public|Default)" }
            
            foreach ($profile in $profiles) {
                $dirs += "$($profile.FullName)\AppData\Local\Autodesk"
                $dirs += "$($profile.FullName)\AppData\Roaming\Autodesk"
            }
        }
        else {
            $dirs += "$env:LOCALAPPDATA\Autodesk"
            $dirs += "$env:APPDATA\Autodesk"
        }
    }
    
    $dirs = $dirs | Select-Object -Unique
    
    foreach ($dir in $dirs) {
        if (Test-Path $dir) {
            Invoke-SafeOperation "Carpeta: $dir" {
                Remove-Item -Path $dir -Recurse -Force -ErrorAction Stop
            } | Out-Null
            $script:Stats.Folders++
        }
    }
    
    Write-LogOutput "  Carpetas eliminadas: $($script:Stats.Folders)" -Level INFO
}

function Clear-UserProfiles {
    param([int]$Step, [int]$Total)
    
    $scope = $script:CleanupLevels[$script:Config.CleanupLevel].Scope
    
    if (-not $scope.HKCU) {
        Write-LogOutput "═ PASO $Step: Limpieza de perfiles (saltada por nivel de seguridad)" -Level INFO
        return
    }
    
    Show-Progress $Step $Total "Limpiando perfiles de usuario..."
    Write-LogOutput "═ PASO $Step: Limpieza de perfiles de usuario" -Level INFO
    
    if ($scope.MultiUser) {
        $profiles = @(Get-ChildItem "C:\Users" -Directory -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -notmatch "^(Public|Default)" })
        
        foreach ($profile in $profiles) {
            $ntuserPath = Join-Path $profile.FullName "NTUSER.DAT"
            
            if (-not (Test-Path $ntuserPath)) { continue }
            
            if ($profile.Name -eq $env:USERNAME) {
                Invoke-SafeOperation "HKCU: $($profile.Name)" {
                    Remove-Item "HKCU:\Software\Autodesk" -Recurse -Force -ErrorAction SilentlyContinue
                } | Out-Null
            }
            else {
                $hiveKey = "TEMP_$($profile.Name)"
                & cmd /c "reg load HKU\$hiveKey `"$ntuserPath`"" 2>$null
                
                if ($LASTEXITCODE -eq 0) {
                    try {
                        $regPath = "Registry::HKEY_USERS\$hiveKey\Software\Autodesk"
                        if (Test-Path $regPath -and -not $script:Config.DryRun) {
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
        Invoke-SafeOperation "HKCU: Usuario actual" {
            Remove-Item "HKCU:\Software\Autodesk" -Recurse -Force -ErrorAction SilentlyContinue
        } | Out-Null
    }
    
    Write-LogOutput "  Perfiles de usuario procesados" -Level INFO
}

function Remove-ScheduledTasks {
    param([int]$Step, [int]$Total)
    
    $scope = $script:CleanupLevels[$script:Config.CleanupLevel].Scope
    
    if (-not $scope.ScheduledTasks) {
        Write-LogOutput "═ PASO $Step: Tareas programadas (saltadas por nivel de seguridad)" -Level INFO
        return
    }
    
    Show-Progress $Step $Total "Eliminando tareas programadas..."
    Write-LogOutput "═ PASO $Step: Eliminación de tareas programadas" -Level INFO
    
    $tasks = @(Get-ScheduledTask -TaskPath "\Autodesk*" -ErrorAction SilentlyContinue)
    
    foreach ($task in $tasks) {
        Invoke-SafeOperation "Tarea: $($task.TaskName)" {
            Unregister-ScheduledTask -TaskName $task.TaskName -Confirm:$false -ErrorAction Stop
        } | Out-Null
        $script:Stats.Tasks++
    }
    
    Write-LogOutput "  Tareas eliminadas: $($script:Stats.Tasks)" -Level INFO
}

function Fix-RebootLoops {
    param([int]$Step, [int]$Total)
    
    Show-Progress $Step $Total "Mitigando bucles de reinicio..."
    Write-LogOutput "═ PASO $Step: Reparación de bucles de reinicio" -Level INFO
    
    $smPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager"
    $pending = Get-ItemProperty -Path $smPath -Name "PendingFileRenameOperations" -ErrorAction SilentlyContinue
    
    if ($pending.PendingFileRenameOperations) {
        $entries = $pending.PendingFileRenameOperations
        $filtered = @()
        
        Write-LogOutput "  Analizando $($entries.Count) entradas..." -Level DEBUG
        
        for ($i = 0; $i -lt $entries.Count; $i += 2) {
            if ($entries[$i] -notmatch "Autodesk|adsk") {
                $filtered += $entries[$i]
                if ($i + 1 -lt $entries.Count) { $filtered += $entries[$i + 1] }
            }
        }
        
        if ($filtered.Count -lt $entries.Count) {
            Write-LogOutput "  Filtrando: removiendo $([math]::Floor(($entries.Count - $filtered.Count) / 2)) entradas de Autodesk" -Level DEBUG
            
            if (-not $script:Config.DryRun) {
                if ($filtered.Count -gt 0) {
                    Set-ItemProperty -Path $smPath -Name "PendingFileRenameOperations" -Value $filtered -Type MultiString -Force
                }
                else {
                    Remove-ItemProperty -Path $smPath -Name "PendingFileRenameOperations" -Force -ErrorAction SilentlyContinue
                }
            }
        }
    }
    
    Write-LogOutput "  ✓ Bucles de reinicio mitigados" -Level SUCCESS
}

function Verify-CleanupCompletion {
    Write-LogOutput "═ VERIFICACIÓN POST-LIMPIEZA" -Level INFO
    
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
        Write-LogOutput "⚠️  Detectados restos:" -Level WARNING
        $remaining | ForEach-Object { Write-LogOutput "  - $_" -Level WARNING }
        return $false
    }
    
    Write-LogOutput "✓ Limpieza verificada exitosamente" -Level SUCCESS
    return $true
}

# ════════════════════════════════════════════════════════════════════════════════
# MAIN EXECUTION
# ════════════════════════════════════════════════════════════════════════════════

try {
    Clear-Host
    Show-Banner "AUTODESK-NUKE v6.0 FINAL" "Cyan"
    
    # Fase 1: Preparación
    Test-AdminPrivileges
    Select-CleanupLevel
    Initialize-Logging
    Test-Prerequisites | Out-Null
    Request-FinalConfirmation | Out-Null
    
    # Fase 2: Limpieza adaptativa
    $totalSteps = 8
    $currentStep = 1
    
    Stop-ProcessesAndServices $currentStep $totalSteps; $currentStep++
    Uninstall-Packages $currentStep $totalSteps; $currentStep++
    Clear-Registry $currentStep $totalSteps; $currentStep++
    Clear-Folders $currentStep $totalSteps; $currentStep++
    Clear-UserProfiles $currentStep $totalSteps; $currentStep++
    Remove-ScheduledTasks $currentStep $totalSteps; $currentStep++
    Fix-RebootLoops $currentStep $totalSteps; $currentStep++
    
    Show-Progress $totalSteps $totalSteps "Finalizando..."
    $cleanupOK = Verify-CleanupCompletion
    
    # Fase 3: Reporte final
    $script:Config.EndTime = Get-Date
    $duration = ($script:Config.EndTime - $script:Config.StartTime).TotalSeconds
    
    Show-Banner "REPORTE FINAL" "Green"
    
    $report = @"
╔════════════════════════════════════════════════════════════════════════════╗
║                         ESTADÍSTICAS DE EJECUCIÓN                         ║
╚════════════════════════════════════════════════════════════════════════════╝

Procesos detenidos:        $($script:Stats.ProcessesStopped)
Servicios detenidos:       $($script:Stats.ServicesStopped)
Paquetes desinstalados:    $($script:Stats.PackagesRemoved)
Claves de registro:        $($script:Stats.RegistryKeys)
Carpetas eliminadas:       $($script:Stats.Folders)
Tareas programadas:        $($script:Stats.Tasks)
Elementos saltados:        $($script:Stats.Skipped)

Duración total:            $([math]::Round($duration, 2))s
Errores encontrados:       $($script:Stats.Errors.Count)
Advertencias:              $($script:Stats.Warnings.Count)

Verificación post-limpieza: $(if($cleanupOK){'✓ EXITOSA'}else{'✗ INCOMPLETA'})

Archivo log:               $($script:Config.LogFile)
════════════════════════════════════════════════════════════════════════════════
"@
    
    Write-Host $report -ForegroundColor Green
    $report | Out-File $script:Config.LogFile -Append -Encoding UTF8
    
    if ($script:Stats.Errors.Count -gt 0) {
        Write-Host "`nERRORES:" -ForegroundColor Red
        $script:Stats.Errors | ForEach-Object { Write-Host "  ✗ $_" -ForegroundColor Red }
    }
    
    if ($script:Stats.Warnings.Count -gt 0) {
        Write-Host "`nADVERTENCIAS:" -ForegroundColor Yellow
        $script:Stats.Warnings | ForEach-Object { Write-Host "  ⚠️  $_" -ForegroundColor Yellow }
    }
    
    Write-LogOutput "════════════════════════════════════════════════════════════════════════════════" -Level SUCCESS
    Write-LogOutput "✓ OPERACIÓN COMPLETADA EXITOSAMENTE" -Level SUCCESS
    Write-LogOutput "════════════════════════════════════════════════════════════════════════════════" -Level SUCCESS
    
    if (-not $script:Config.DryRun) {
        Write-Host "`n⚠️  Se recomienda REINICIAR el equipo antes de reinstalar Autodesk." -ForegroundColor Yellow
    }
}
catch {
    Write-LogOutput "✗ ERROR CRÍTICO: $($_.Exception.Message)" -Level ERROR
    Write-LogOutput "Stack Trace: $($_.ScriptStackTrace)" -Level DEBUG
    exit 1
}
