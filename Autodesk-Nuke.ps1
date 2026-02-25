<#
.SYNOPSIS
    Autodesk Comprehensive Cleanup Script
.DESCRIPTION
    Este script realiza una limpieza profunda de las instalaciones, archivos residuales, 
    y claves de registro de Autodesk. Está diseñado para solucionar problemas comunes de 
    instalación, como el bucle "Reinicie antes de empezar la instalación" causado por 
    archivos o claves de registro bloqueados (PendingFileRenameOperations).
.NOTES
    Autor: SSM-Dealis
    Versión: 2.0.1
    Uso: Ejecutar como Administrador. Importante para la publicación en GitHub.
#>

# -----------------------------------------------------------------------------
# 1. VERIFICACIÓN DE PRIVILEGIOS DE ADMINISTRADOR
# -----------------------------------------------------------------------------
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
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

# -----------------------------------------------------------------------------
# 2. DETENCIÓN DE PROCESOS Y SERVICIOS
# -----------------------------------------------------------------------------
Write-Host "`n[PASO 1] Deteniendo servicios y procesos de Autodesk y FlexNet..." -ForegroundColor Cyan

$services = @(
    "AdskLicensingService", 
    "AdAppMgrSvc", 
    "AutodeskDesktopApp",
    "AutodeskDesktopAppService",
    "AGSService",
    "FlexNet Licensing Service",
    "FlexNet Licensing Service 64"
)
foreach ($srv in $services) { 
    $service = Get-Service -Name $srv -ErrorAction SilentlyContinue
    if ($service) {
        if ($service.Status -eq 'Running') {
            Write-Host "   Deteniendo servicio: $srv" -ForegroundColor Yellow
            Stop-Service -Name $srv -Force -ErrorAction SilentlyContinue
        }
    }
}

$procesos = @(
    "acad", "inventor", "AdskLicensingService", "AdAppMgrSvc", 
    "AutodeskDesktopApp", "AdODIS", "AdskIdentityManager", "GenuineService",
    "AdskLicensingAgent", "AcEventSync", "AcQMod", "Autodesk Access UI Host", 
    "AdskAccessCore", "ADPClientService",
    "FNPLicensingService", "FNPLicensingService64", "LMgrd", "Adlmint"
)
foreach ($proc in $procesos) { 
    $process = Get-Process -Name $proc -ErrorAction SilentlyContinue
    if ($process) {
        Write-Host "   Terminando proceso: $proc" -ForegroundColor Yellow
        Stop-Process -Name $proc -Force -ErrorAction SilentlyContinue
    }
}

Write-Host "[OK] Procesos y servicios detenidos." -ForegroundColor Green


# -----------------------------------------------------------------------------
# 3. DESINSTALACIÓN DE PAQUETES MSI (Registro)
# -----------------------------------------------------------------------------
Write-Host "`n[PASO 2] Ejecutando desinstaladores silenciosos principales de Autodesk..." -ForegroundColor Cyan

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
# 4. ELIMINACIÓN DE CARPETAS Y ARCHIVOS RESIDUALES
# -----------------------------------------------------------------------------
Write-Host "`n[PASO 3] Eliminando carpetas residuales y archivos temporales..." -ForegroundColor Cyan

$dirs = @(
    "C:\Autodesk",
    "$env:ProgramFiles\Autodesk", 
    "${env:ProgramFiles(x86)}\Autodesk", 
    "$env:ProgramData\Autodesk",
    "$env:LOCALAPPDATA\Autodesk", 
    "$env:APPDATA\Autodesk",
    "$env:ProgramFiles\Common Files\Autodesk Shared",
    "${env:ProgramFiles(x86)}\Common Files\Autodesk Shared",
    "C:\Users\Public\Documents\Autodesk",
    "C:\Users\Public\Autodesk",
    "$env:TEMP",
    "$env:WINDIR\Temp"
)

foreach ($dir in $dirs) {
    if (Test-Path $dir) { 
        Write-Host "   Eliminando: $dir" -ForegroundColor DarkGray
        # Evitamos errores fatales si hay archivos en uso en Temp
        Remove-Item -Path "$dir\*" -Recurse -Force -ErrorAction SilentlyContinue 
        
        # Intentar borrar el directorio raíz si no es Temp
        if ($dir -notmatch "Temp$") {
            Remove-Item -Path $dir -Recurse -Force -ErrorAction SilentlyContinue
        }
    } 
}

# Eliminar solo archivos adsk en FLEXnet superficialmente (para no afectar otras licencias)
$flexNetPath = "$env:ProgramData\FLEXnet"
if (Test-Path $flexNetPath) {
    Write-Host "   Limpiando archivos de Autodesk en FLEXnet..." -ForegroundColor DarkGray
    Get-ChildItem -Path $flexNetPath -Filter "adsk*" -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
}

Write-Host "[OK] Carpetas residuales procesadas." -ForegroundColor Green


# -----------------------------------------------------------------------------
# 5. LIMPIEZA DE REGISTRO Y REINICIO DE BUCLE
# -----------------------------------------------------------------------------
Write-Host "`n[PASO 4] Limpiando el Registro de Windows y solucionando bucles de reinicio..." -ForegroundColor Cyan

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
