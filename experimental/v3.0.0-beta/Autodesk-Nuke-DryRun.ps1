<#
.SYNOPSIS
    Herramienta Profunda de Limpieza de Autodesk.
    Version: 3.0.0 "Fusion"
    
.DESCRIPTION
    Script ultra-optimizado para la eliminación total de rastro de Autodesk.
    Incluye: Logging detallado, Barra de Progreso, y Eliminación de Tareas Programadas.

.PARAMETER AllUsers
    Limpia perfiles de todos los usuarios (AppData y Registro).
.PARAMETER LogPath
    Ruta personalizada para el archivo de log. Por defecto en %TEMP%.
.PARAMETER CleanTasks
    Si se marca, elimina tareas programadas relacionadas con Autodesk.

.NOTES
    Autor: Contribuidor de Comunidad
#>

param (
    [switch]$AllUsers,
    [string]$LogPath = "$env:TEMP\Autodesk_Nuke_Improved.log",
    [switch]$CleanTasks = $true,
    [switch]$WhatIf
)

# --- Funciones de Utilidad ---
function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logLine = "[$timestamp] [$Level] $Message"
    Add-Content -Path $LogPath -Value $logLine -ErrorAction SilentlyContinue
    
    $color = switch ($Level) {
        "ERROR" { "Red" }
        "WARNING" { "Yellow" }
        "SUCCESS" { "Green" }
        default { "Gray" }
    }
    Write-Host "   $logLine" -ForegroundColor $color
}

# 1. Verificación de Privilegios
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.BuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "[!] Se requieren privilegios de Administrador." -ForegroundColor Red
    if ($PSCmdlet.ShouldProcess("Reiniciar como Admin")) {
        Start-Process PowerShell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    }
    exit
}

Clear-Host
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "   AUTODESK NUCLEAR CLEANUP TOOL v3.0 (Improved)" -ForegroundColor Cyan
Write-Host "   Desarrollado para entornos de Windows" -ForegroundColor Yellow
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Log "Iniciando proceso de limpieza profunda."

# 2. Configuración Dinámica
if (-not $PSBoundParameters.ContainsKey('AllUsers')) {
    $response = Read-Host "¿Limpia perfiles de TODOS los usuarios? (Y/N)"
    if ($response -match "^[Yy]$") { $AllUsers = $true }
}

# --- BARRA DE PROGRESO TOTAL ---
$steps = 7
$currentStep = 0

# STEP 1: Procesos y Servicios
$currentStep++
Write-Progress -Activity "Paso $currentStep/$steps: Limpieza de Procesos" -Status "Deteniendo servicios de Autodesk..." -PercentComplete (($currentStep/$steps)*100)

$procList = @("AutodeskAccess", "AdskIdentityManager", "AdSSO", "Node", "AdskLicensingService", "AutodeskDesktopApp")
foreach ($p in $procList) {
    if (Get-Process -Name $p -ErrorAction SilentlyContinue) {
        Write-Log "Terminando proceso: $p"
        if (-not $WhatIf) { Get-Process -Name $p | Stop-Process -Force -ErrorAction SilentlyContinue }
    }
}

$services = Get-Service | Where-Object { $_.Name -match "Autodesk" -or $_.DisplayName -match "Autodesk" }
foreach ($s in $services) {
    Write-Log "Deteniendo servicio: $($s.Name)"
    if (-not $WhatIf) { Stop-Service -Name $s.Name -Force -ErrorAction SilentlyContinue }
}

# STEP 2: Tareas Programadas
$currentStep++
Write-Progress -Activity "Paso $currentStep/$steps: Tareas Programadas" -Status "Eliminando tareas residuales..." -PercentComplete (($currentStep/$steps)*100)
if ($CleanTasks) {
    $tasks = Get-ScheduledTask -TaskPath "\Autodesk*" -ErrorAction SilentlyContinue
    foreach ($t in $tasks) {
        Write-Log "Eliminando tarea: $($t.TaskName)"
        if (-not $WhatIf) { Unregister-ScheduledTask -TaskName $t.TaskName -Confirm:$false -ErrorAction SilentlyContinue }
    }
}

# STEP 3: Desinstaladores MSI/ODIS
$currentStep++
Write-Progress -Activity "Paso $currentStep/$steps: Desinstalación MSI" -Status "Ejecutando desinstaladores automáticos..." -PercentComplete (($currentStep/$steps)*100)

$regPaths = @("HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*", "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*")
$items = Get-ItemProperty $regPaths -ErrorAction SilentlyContinue | Where-Object { ($_.DisplayName -match "Autodesk" -or $_.Publisher -match "Autodesk") -and ($_.UninstallString) }

foreach ($item in $items) {
    Write-Log "Ejecutando desinstalador para: $($item.DisplayName)"
    if ($WhatIf) { continue }
    
    if ($item.UninstallString -match "msiexec") {
        $args = ($item.UninstallString -ireplace "msiexec.exe","" -ireplace "/I","/X") + " /quiet /qn /norestart"
        Start-Process "msiexec.exe" -ArgumentList $args -Wait -NoNewWindow
    } else {
        # Para ODIS u otros
        $cmd = $item.UninstallString -replace '"', ''
        if (Test-Path $cmd) { Start-Process $cmd -ArgumentList "-q -i uninstall" -Wait -NoNewWindow }
    }
}

# STEP 4: Limpieza de Registro (HKLM / HKCR)
$currentStep++
Write-Progress -Activity "Paso $currentStep/$steps: Registro Global" -Status "Limpiando HKLM y HKCR..." -PercentComplete (($currentStep/$steps)*100)
$globalKeys = @("HKLM:\SOFTWARE\Autodesk", "HKLM:\SOFTWARE\Wow6432Node\Autodesk", "HKCR:\Autodesk", "HKLM:\SOFTWARE\Classes\Installer\Products\*")
foreach ($key in $globalKeys) {
    if (Test-Path $key) {
        if ($key -match "Products") {
            Get-ItemProperty $key | Where-Object { $_.ProductName -match "Autodesk" } | ForEach-Object { 
                Write-Log "Borrando producto MSI: $($_.ProductName)"
                if (-not $WhatIf) { Remove-Item $_.PSPath -Recurse -Force }
            }
        } else {
            Write-Log "Borrando clave: $key"
            if (-not $WhatIf) { Remove-Item $key -Recurse -Force -ErrorAction SilentlyContinue }
        }
    }
}

# STEP 5: Registro de Usuarios (HKCU / NTUSER)
$currentStep++
Write-Progress -Activity "Paso $currentStep/$steps: Registro de Usuarios" -Status "Limpiando perfiles de usuario..." -PercentComplete (($currentStep/$steps)*100)
$userKeys = @("Software\Autodesk", "Software\Microsoft\Windows\CurrentVersion\Uninstall\*")

if ($AllUsers) {
    $profiles = Get-ChildItem "C:\Users" -Directory -Exclude "Public", "Default"
    foreach ($p in $profiles) {
        $path = Join-Path $p.FullName "NTUSER.DAT"
        if (Test-Path $path) {
            $hiveName = "HKU_Clean_$($p.Name)"
            if (-not $WhatIf) {
                reg load "HKU\$hiveName" "$path" > $null
                foreach ($uk in $userKeys) {
                    $fullUk = "Registry::HKEY_USERS\$hiveName\$uk"
                    if (Test-Path $fullUk) { Remove-Item $fullUk -Recurse -Force -ErrorAction SilentlyContinue }
                }
                [gc]::Collect(); Start-Sleep -s 1
                reg unload "HKU\$hiveName" > $null
            }
            Write-Log "Perfil limpiado: $($p.Name)"
        }
    }
} else {
    foreach ($uk in $userKeys) {
        $fullPath = "HKCU:\$uk"
        if (Test-Path $fullPath) { 
            Write-Log "Borrando HKCU: $uk"
            if (-not $WhatIf) { Remove-Item $fullPath -Recurse -Force -ErrorAction SilentlyContinue }
        }
    }
}

# STEP 6: Archivos y Carpetas (Dinámico)
$currentStep++
Write-Progress -Activity "Paso $currentStep/$steps: Archivos" -Status "Eliminando carpetas residuales..." -PercentComplete (($currentStep/$steps)*100)
$basePaths = @("C:\Program Files\Autodesk", "C:\ProgramData\Autodesk", "C:\Program Files (x86)\Autodesk", "C:\Users\Public\Documents\Autodesk")
if ($AllUsers) {
    $profiles | ForEach-Object { $basePaths += Join-Path $_.FullName "AppData\Local\Autodesk"; $basePaths += Join-Path $_.FullName "AppData\Roaming\Autodesk" }
} else {
    $basePaths += "$env:LOCALAPPDATA\Autodesk"; $basePaths += "$env:APPDATA\Autodesk"
}

foreach ($bp in $basePaths) {
    if (Test-Path $bp) {
        Write-Log "Borrando carpeta: $bp"
        if (-not $WhatIf) { Remove-Item $bp -Recurse -Force -ErrorAction SilentlyContinue }
    }
}

# STEP 7: Finalización y Bucles de Reinicio
$currentStep++
Write-Progress -Activity "Paso $currentStep/$steps: Finalizando" -Status "Limpiando bucles de reinicio..." -PercentComplete 100

$smPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager"
if (Get-ItemProperty -Path $smPath -Name "PendingFileRenameOperations" -ErrorAction SilentlyContinue) {
    Write-Log "Limpiando PendingFileRenameOperations"
    if (-not $WhatIf) { Remove-ItemProperty -Path $smPath -Name "PendingFileRenameOperations" -Force }
}

Write-Log "PROCESO FINALIZADO" "SUCCESS"
Write-Progress -Activity "Limpieza Completada" -Completed
Write-Host "`n[OK] El log de la operación se encuentra en: $LogPath" -ForegroundColor Cyan
Write-Host "Se recomienda REINICIAR el equipo ahora." -ForegroundColor Yellow
