<#
.SYNOPSIS
    Herramienta de eliminación radical para productos Autodesk v3.0 (Mejorado).
    Version: 3.0.0-Optimized

.DESCRIPTION
    Script refactorizado con manejo robusto de errores, logging persistente,
    validaciones de seguridad y arquitectura modular.

.PARAMETER AllUsers
    Limpiar perfiles (AppData/Registro) de todos los usuarios.

.PARAMETER DryRun
    Simular sin realizar cambios reales (solo logging).

.PARAMETER LogPath
    Ruta personalizada para archivo de log.

.NOTES
    Autor: SSM-Dealis (v3.0 Mejorado)
    Versión: 3.0.0-Optimized
    Requiere: PowerShell 5.0+, Privilegios de Administrador
#>

param (
    [switch]$AllUsers,
    [switch]$DryRun,
    [string]$LogPath = "$env:TEMP\Autodesk_Cleanup_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
)

# ============================================================================
# VARIABLES GLOBALES Y CONFIGURACIÓN
# ============================================================================
$script:LogFile = $LogPath
$script:DryRun = $DryRun
$script:CleanupReport = $null

# Colores para output
$Colors = @{
    Success = "Green"
    Error   = "Red"
    Warning = "Yellow"
    Info    = "Cyan"
    Debug   = "Gray"
}

# ============================================================================
# FUNCIONES DE LOGGING
# ============================================================================

function Initialize-Logging {
    "═════════════════════════════════════════════════════════════" | Out-File $LogFile -Encoding UTF8
    "Inicio de limpieza Autodesk - $(Get-Date)" | Out-File $LogFile -Append
    "Sistema: Windows $([System.Environment]::OSVersion.Version.Major).$([System.Environment]::OSVersion.Version.Minor)" | Out-File $LogFile -Append
    "Usuario: $env:USERNAME | Máquina: $env:COMPUTERNAME" | Out-File $LogFile -Append
    "═════════════════════════════════════════════════════════════" | Out-File $LogFile -Append
    Write-Host "[LOG] Archivo creado: $LogFile" -ForegroundColor DarkGray
}

function Write-Log {
    param(
        [string]$Message,
        [ValidateSet("SUCCESS", "ERROR", "WARNING", "INFO", "DEBUG")][string]$Level = "INFO",
        [switch]$NoConsole
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
    $logEntry = "[$timestamp] [$Level] $Message"
    
    # Escribir a archivo siempre
    $logEntry | Out-File $LogFile -Append -Encoding UTF8
    
    # Escribir a consola (a menos que se especifique lo contrario)
    if (-not $NoConsole) {
        Write-Host $logEntry -ForegroundColor $Colors[$Level]
    }
}

# ============================================================================
# FUNCIONES DE VALIDACIÓN Y SEGURIDAD
# ============================================================================

function Test-AdminPrivileges {
    Write-Log "Verificando privilegios de Administrador..." -Level INFO
    
    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.BuiltInRole]::Administrator)
    
    if (-not $isAdmin) {
        Write-Log "Sin privilegios de Administrador. Elevando..." -Level WARNING
        try {
            $argList = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
            if ($AllUsers) { $argList += " -AllUsers" }
            if ($DryRun) { $argList += " -DryRun" }
            
            Start-Process PowerShell -ArgumentList $argList -Verb RunAs -Wait
            exit 0
        }
        catch {
            Write-Log "Elevación fallida. Ejecuta como Administrador manualmente." -Level ERROR
            exit 1
        }
    }
    
    Write-Log "✓ Ejecutando con permisos de Administrador" -Level SUCCESS
    return $true
}

function Test-SystemReadiness {
    Write-Log "Validando estado del sistema..." -Level INFO
    
    # Verificar espacio en disco
    $diskSpace = (Get-Item C:\ | Measure-Object -Property FreeSpace -ErrorAction SilentlyContinue).FreeSpace / 1GB
    if ($diskSpace -lt 0.5) {
        Write-Log "⚠ Espacio en disco crítico: ${diskSpace}GB disponibles" -Level WARNING
    }
    
    # Verificar procesos antivirus activos
    $antivirusProcesses = Get-Process | Where-Object { $_.Name -match "^(MsMpEng|avast|kaspersky|bitdefender)" -ErrorAction SilentlyContinue }
    if ($antivirusProcesses) {
        Write-Log "⚠ Antivirus activo detectado. Puede causar bloqueos de archivos." -Level WARNING
    }
    
    return $true
}

function Test-AutodeskPresence {
    Write-Log "Escaneando presencia de Autodesk..." -Level INFO
    
    $found = @()
    $regPaths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )
    
    foreach ($path in $regPaths) {
        $found += Get-ItemProperty $path -ErrorAction SilentlyContinue | 
            Where-Object { $_.DisplayName -match "Autodesk|Autocad|Revit|Inventor|Fusion" }
    }
    
    if ($found.Count -eq 0) {
        Write-Log "⚠ No se detectaron productos Autodesk instalados" -Level WARNING
        return $false
    }
    
    Write-Log "Detectados $($found.Count) producto(s) Autodesk:" -Level INFO
    $found | ForEach-Object { 
        Write-Log "  • $($_.DisplayName) (v$($_.DisplayVersion))" -Level INFO 
    }
    
    return $true
}

function Request-UserConfirmation {
    param([string]$Message)
    
    Write-Host "`n" -ForegroundColor Yellow
    Write-Host "╔════════════════════════════════════════════════════════╗" -ForegroundColor Yellow
    Write-Host "║ ADVERTENCIA: OPERACIÓN DESTRUCTIVA" -ForegroundColor Yellow
    Write-Host "╚════════════════════════════════════════════════════════╝" -ForegroundColor Yellow
    Write-Host $Message -ForegroundColor Yellow
    Write-Host ""
    
    if ($DryRun) {
        Write-Host "Modo: DRY-RUN (sin cambios reales)" -ForegroundColor Green
    }
    
    $response = Read-Host "¿Continuar? (escriba 'sí' para confirmar, Enter para cancelar)"
    if ($response -ne "sí") {
        Write-Log "Operación cancelada por usuario" -Level INFO
        exit 0
    }
    
    return $true
}

# ============================================================================
# FUNCIONES DE DETENCIÓN DE PROCESOS/SERVICIOS
# ============================================================================

function Stop-AutodeskProcesses {
    Write-Log "Paso 1: Deteniendo procesos Autodesk..." -Level INFO
    
    $criticalProcesses = @("AutodeskAccess", "AdskIdentityManager", "AdSSO", "AdLM", "Node", "Autodesk*")
    $stoppedCount = 0
    
    foreach ($processPattern in $criticalProcesses) {
        $processes = @(Get-Process -Name $processPattern -ErrorAction SilentlyContinue)
        
        foreach ($proc in $processes) {
            if ($DryRun) {
                Write-Log "[DRY-RUN] Habría detenido proceso: $($proc.Name) (PID: $($proc.Id))" -Level INFO
                $stoppedCount++
                continue
            }
            
            try {
                Write-Log "Deteniendo: $($proc.Name) (PID: $($proc.Id))" -Level INFO
                $proc | Stop-Process -Force -ErrorAction Stop
                $stoppedCount++
                Write-Log "✓ Detenido: $($proc.Name)" -Level SUCCESS
            }
            catch {
                Write-Log "✗ Error deteniendo $($proc.Name): $($_.Exception.Message)" -Level ERROR
            }
        }
    }
    
    Write-Log "✓ Procesos detenidos: $stoppedCount" -Level SUCCESS
    return $stoppedCount
}

function Stop-AutodeskServices {
    Write-Log "Paso 2: Deteniendo servicios Autodesk..." -Level INFO
    
    $services = Get-Service -ErrorAction SilentlyContinue | 
        Where-Object { $_.Name -match "Autodesk|Adsk|AdLM|FlexNet" -or $_.DisplayName -match "Autodesk" }
    
    $stoppedCount = 0
    
    foreach ($svc in $services) {
        if ($DryRun) {
            Write-Log "[DRY-RUN] Habría detenido servicio: $($svc.Name)" -Level INFO
            $stoppedCount++
            continue
        }
        
        Write-Log "Deteniendo servicio: $($svc.Name)..." -Level INFO
        
        try {
            # Intento 1: Parada normal
            $svc | Stop-Service -Force -ErrorAction SilentlyContinue
            Start-Sleep -Milliseconds 500
            
            # Verificar estado
            $currentStatus = (Get-Service -Name $svc.Name -ErrorAction SilentlyContinue).Status
            
            if ($currentStatus -ne 'Stopped') {
                Write-Log "⚠ Servicio resistió parada normal. Forzando..." -Level WARNING
                
                # Obtener PID del servicio
                $wmiService = Get-WmiObject -Class Win32_Service -Filter "Name='$($svc.Name)'" -ErrorAction SilentlyContinue
                
                if ($wmiService -and $wmiService.ProcessId -gt 0) {
                    Stop-Process -Id $wmiService.ProcessId -Force -ErrorAction SilentlyContinue
                }
                else {
                    taskkill /F /FI "SERVICES eq $($svc.Name)" 2>$null | Out-Null
                }
            }
            
            Write-Log "✓ Servicio detenido: $($svc.Name)" -Level SUCCESS
            $stoppedCount++
        }
        catch {
            Write-Log "✗ Error deteniendo servicio $($svc.Name): $($_.Exception.Message)" -Level ERROR
        }
    }
    
    Write-Log "✓ Servicios detenidos: $stoppedCount" -Level SUCCESS
    return $stoppedCount
}

# ============================================================================
# FUNCIONES DE LIMPIEZA
# ============================================================================

function Remove-RegistryPath {
    param(
        [string]$Path,
        [switch]$Recurse = $true
    )
    
    if (-not (Test-Path $Path)) { return 0 }
    
    $removedCount = 0
    
    try {
        if ($DryRun) {
            Write-Log "[DRY-RUN] Habría eliminado: $Path" -Level INFO
            return 1
        }
        
        Remove-Item -Path $Path -Recurse:$Recurse -Force -ErrorAction Stop
        Write-Log "✓ Eliminada clave: $Path" -Level SUCCESS
        $removedCount++
    }
    catch {
        Write-Log "✗ Error eliminando $Path : $($_.Exception.Message)" -Level ERROR
    }
    
    return $removedCount
}

function Remove-AutodeskFolder {
    param([string]$Path)
    
    if (-not (Test-Path $Path)) { return 0 }
    
    $removedCount = 0
    
    try {
        if ($DryRun) {
            $size = (Get-ChildItem -Path $Path -Recurse -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum / 1MB
            Write-Log "[DRY-RUN] Habría eliminado: $Path (${size}MB)" -Level INFO
            return 1
        }
        
        Remove-Item -Path $Path -Recurse -Force -ErrorAction Stop
        Write-Log "✓ Carpeta eliminada: $Path" -Level SUCCESS
        $removedCount++
    }
    catch [System.IO.IOException] {
        Write-Log "⚠ Carpeta bloqueada: $Path. Aplicando estrategias de desbloqueo..." -Level WARNING
        $removedCount = Unlock-AndRemoveFolder -Path $Path
    }
    catch {
        Write-Log "✗ Error eliminando $Path : $($_.Exception.Message)" -Level ERROR
    }
    
    return $removedCount
}

function Unlock-AndRemoveFolder {
    param([string]$Path)
    
    $maxRetries = 3
    $retryCount = 0
    
    while ($retryCount -lt $maxRetries) {
        try {
            # Cambiar atributos
            Get-ChildItem -Path $Path -Recurse -Force -ErrorAction SilentlyContinue | 
                ForEach-Object { $_.Attributes = "Normal" }
            
            Remove-Item -Path $Path -Recurse -Force -ErrorAction Stop
            Write-Log "✓ Desbloqueada y eliminada: $Path" -Level SUCCESS
            return 1
        }
        catch {
            $retryCount++
            if ($retryCount -lt $maxRetries) {
                Write-Log "  Reintentando ($retryCount/$maxRetries)..." -Level WARNING
                Start-Sleep -Seconds 2
            }
        }
    }
    
    Write-Log "✗ No se pudo eliminar después de $maxRetries intentos" -Level ERROR
    return 0
}

# ============================================================================
# LIMPIEZA DEL REGISTRO
# ============================================================================

function Clear-RegistryKeys {
    Write-Log "Paso 3: Limpiando claves de registro..." -Level INFO
    
    $removedCount = 0
    
    $regKeys = @(
        "HKLM:\SOFTWARE\Autodesk",
        "HKCU:\SOFTWARE\Autodesk",
        "HKLM:\SOFTWARE\Wow6432Node\Autodesk",
        "HKCR:\Autodesk"
    )
    
    foreach ($key in $regKeys) {
        $removedCount += Remove-RegistryPath -Path $key
    }
    
    # Limpiar entradas fantasma
    Write-Log "  Limpiando registros de desinstalación..." -Level INFO
    
    $uninstallPaths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )
    
    foreach ($path in $uninstallPaths) {
        $keys = Get-ItemProperty $path -ErrorAction SilentlyContinue | 
            Where-Object { $_.DisplayName -match "Autodesk|Autocad" }
        
        foreach ($key in $keys) {
            if ($DryRun) {
                Write-Log "[DRY-RUN] Habría eliminado registro fantasma: $($key.DisplayName)" -Level INFO
                $removedCount++
            }
            else {
                Write-Log "Eliminando registro: $($key.DisplayName)" -Level INFO
                Remove-Item -Path $key.PSPath -Recurse -Force -ErrorAction SilentlyContinue
                $removedCount++
            }
        }
    }
    
    Write-Log "✓ Claves de registro limpiadas: $removedCount" -Level SUCCESS
    return $removedCount
}

# ============================================================================
# LIMPIEZA DE CARPETAS
# ============================================================================

function Clear-Folders {
    Write-Log "Paso 4: Eliminando carpetas de Autodesk..." -Level INFO
    
    $removedCount = 0
    
    $dirs = @(
        "C:\Program Files\Autodesk",
        "C:\Program Files\Common Files\Autodesk Shared",
        "C:\Program Files (x86)\Autodesk",
        "C:\Program Files (x86)\Common Files\Autodesk Shared",
        "C:\ProgramData\Autodesk",
        "C:\Users\Public\Documents\Autodesk",
        "$env:ProgramData\FLEXnet",
        "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Autodesk"
    )
    
    if ($AllUsers) {
        Write-Log "Incluyendo AppData de todos los usuarios..." -Level INFO
        
        $userProfiles = Get-ChildItem "C:\Users" -Directory -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -notmatch "^(Public|Default|All Users|Default User|NetworkService)" }
        
        foreach ($profile in $userProfiles) {
            $dirs += "$($profile.FullName)\AppData\Local\Autodesk"
            $dirs += "$($profile.FullName)\AppData\Roaming\Autodesk"
        }
    }
    else {
        $dirs += "$env:LOCALAPPDATA\Autodesk"
        $dirs += "$env:APPDATA\Autodesk"
    }
    
    # Eliminar duplicados
    $dirs = $dirs | Select-Object -Unique
    
    foreach ($dir in $dirs) {
        $removedCount += Remove-AutodeskFolder -Path $dir
    }
    
    Write-Log "✓ Carpetas procesadas: $removedCount" -Level SUCCESS
    return $removedCount
}

# ============================================================================
# LIMPIEZA MULTI-USUARIO
# ============================================================================

function Clear-UserProfiles {
    if (-not $AllUsers) { return 0 }
    
    Write-Log "Paso 5: Limpiando perfiles de usuario (HKCU)..." -Level INFO
    
    $userProfiles = Get-ChildItem "C:\Users" -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -notmatch "^(Public|Default|NetworkService)" }
    
    $cleanedCount = 0
    
    foreach ($profile in $userProfiles) {
        $ntuserPath = Join-Path $profile.FullName "NTUSER.DAT"
        
        if (-not (Test-Path $ntuserPath)) { continue }
        
        Write-Log "  Procesando perfil: $($profile.Name)" -Level INFO
        
        if ($profile.Name -eq $env:USERNAME) {
            # Usuario actual
            $subPaths = @("Software\Autodesk", "Software\Microsoft\Installer\Products")
            
            foreach ($subPath in $subPaths) {
                $fullPath = "HKCU:\$subPath"
                if (Test-Path $fullPath) {
                    $cleanedCount += Remove-RegistryPath -Path $fullPath
                }
            }
        }
        else {
            # Usuario offline - montar hive
            $hiveKey = "TEMP_$($profile.Name)"
            $registryPath = "HKEY_USERS\$hiveKey"
            
            $loadResult = & cmd /c "reg load $registryPath `"$ntuserPath`"" 2>&1
            if ($LASTEXITCODE -eq 0) {
                Write-Log "    Hive montado correctamente" -Level INFO
                
                try {
                    $fullPath = "Registry::HKEY_USERS\$hiveKey\Software\Autodesk"
                    if (Test-Path $fullPath) {
                        $cleanedCount += Remove-RegistryPath -Path $fullPath
                    }
                }
                finally {
                    # Descargar hive
                    [System.GC]::Collect()
                    [System.GC]::WaitForPendingFinalizers()
                    Start-Sleep -Milliseconds 500
                    
                    & cmd /c "reg unload $registryPath" 2>$null | Out-Null
                    Write-Log "    Hive descargado" -Level INFO
                }
            }
            else {
                Write-Log "    ⚠ No se pudo montar hive (puede estar en uso)" -Level WARNING
            }
        }
    }
    
    Write-Log "✓ Perfiles de usuario limpiados: $cleanedCount" -Level SUCCESS
    return $cleanedCount
}

# ============================================================================
# VERIFICACIÓN POST-LIMPIEZA
# ============================================================================

function Verify-CleanupCompletion {
    Write-Log "Paso 6: Verificando completitud de la limpieza..." -Level INFO
    
    $remaining = @()
    
    # Verificar claves de registro
    if (Test-Path "HKLM:\SOFTWARE\Autodesk") {
        $remaining += "Clave HKLM\SOFTWARE\Autodesk"
    }
    
    # Verificar carpetas principales
    if (Test-Path "C:\Program Files\Autodesk") {
        $remaining += "Carpeta C:\Program Files\Autodesk"
    }
    
    # Verificar servicios
    $services = Get-Service -ErrorAction SilentlyContinue | 
        Where-Object { $_.Name -match "Autodesk|Adsk" }
    if ($services) {
        $remaining += "Servicios: $($services.Name -join ', ')"
    }
    
    # Verificar procesos
    $processes = Get-Process -ErrorAction SilentlyContinue | 
        Where-Object { $_.Name -match "Autodesk|Adsk|AutoCAD" }
    if ($processes) {
        $remaining += "Procesos: $($processes.Name -join ', ')"
    }
    
    if ($remaining.Count -gt 0) {
        Write-Log "⚠ Detectados restos de Autodesk:" -Level WARNING
        $remaining | ForEach-Object { Write-Log "  - $_" -Level WARNING }
        return $false
    }
    
    Write-Log "✓ Limpieza verificada exitosamente" -Level SUCCESS
    return $true
}

# ============================================================================
# REPORTE FINAL
# ============================================================================

function Show-CompletionReport {
    param(
        [int]$ProcessesStopped = 0,
        [int]$ServicesStopped = 0,
        [int]$FoldersRemoved = 0,
        [int]$RegistryKeysRemoved = 0
    )
    
    $report = @"

╔════════════════════════════════════════════════════════╗
║              REPORTE DE LIMPIEZA FINAL                ║
╚════════════════════════════════════════════════════════╝

Procesos detenidos:       $ProcessesStopped
Servicios detenidos:      $ServicesStopped
Carpetas eliminadas:      $FoldersRemoved
Claves de registro:       $RegistryKeysRemoved

Log detallado: $LogFile

"@
    
    if ($DryRun) {
        $report += "Modo: DRY-RUN - No se realizaron cambios reales`n"
    }
    else {
        $report += "IMPORTANTE: Se recomienda reiniciar antes de reinstalar Autodesk.`n"
    }
    
    Write-Host $report -ForegroundColor Green
    $report | Out-File $LogFile -Append -Encoding UTF8
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

try {
    Initialize-Logging
    
    Write-Log "═════════════════════════════════════════════════════════════" -Level INFO
    Write-Log "Inicio de Limpieza Autodesk v3.0" -Level INFO
    Write-Log "═════════════════════════════════════════════════════════════" -Level INFO
    
    # Validaciones iniciales
    Test-AdminPrivileges | Out-Null
    Test-SystemReadiness | Out-Null
    Test-AutodeskPresence | Out-Null
    
    # Confirmación del usuario
    Request-UserConfirmation "Este script eliminará TODA la presencia de Autodesk del sistema.`nEsta acción es irreversible." | Out-Null
    
    # Ejecutar limpieza
    $procCount = Stop-AutodeskProcesses
    $svcCount = Stop-AutodeskServices
    Start-Sleep -Seconds 1
    
    $regCount = Clear-RegistryKeys
    $folderCount = Clear-Folders
    $userCount = Clear-UserProfiles
    
    # Verificación
    Verify-CleanupCompletion | Out-Null
    
    # Reporte
    Show-CompletionReport -ProcessesStopped $procCount -ServicesStopped $svcCount `
                          -FoldersRemoved $folderCount -RegistryKeysRemoved $regCount
    
    Write-Log "═════════════════════════════════════════════════════════════" -Level INFO
    Write-Log "✓ LIMPIEZA COMPLETADA EXITOSAMENTE" -Level SUCCESS
    Write-Log "═════════════════════════════════════════════════════════════" -Level INFO
}
catch {
    Write-Log "✗ ERROR CRÍTICO: $($_.Exception.Message)" -Level ERROR
    Write-Log "Stack Trace: $($_.ScriptStackTrace)" -Level DEBUG
    exit 1
}
