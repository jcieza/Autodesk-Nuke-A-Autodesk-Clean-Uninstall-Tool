<#
.SYNOPSIS
    Autodesk-Nuke v6.3 ULTIMATE - Herramienta definitiva para casos complejos
    
.DESCRIPTION
    Script de limpieza de Autodesk de maxima cobertura. Disenado para resolver
    los casos mas problematicos que la v2.0.2 no puede manejar (el 8% restante).
    
    Combina TODAS las capacidades de las 10 versiones previas:
    - Desinstalacion real MSI, ODIS, AdskUninstallHelper, RemoveODIS, Licensing, Identity Manager
    - Limpieza de registro HKLM, HKCU, HKCR, Installer\Products, multi-usuario NTUSER.DAT
    - Limpieza de TODAS las carpetas conocidas incluyendo Common Files, Public, Temp
    - Reparacion de bucles de reinicio (PendingFileRename + RebootRequired)
    - Tareas programadas, variables de entorno, servicios con kill forzado via CIM
    - Niveles de profundidad BASIC/ADVANCED/ENTERPRISE
    - DryRun, Logging completo, Verificacion post-limpieza
    
.PARAMETER DryRun
    Simular sin cambios reales. Muestra todo lo que haria.
    
.PARAMETER LogPath
    Ruta personalizada para archivo de log.
    
.PARAMETER SkipValidation
    Saltar validaciones iniciales (solo testing).
    
.PARAMETER QuietMode
    Reducir output de consola (solo logs a archivo).
    
.NOTES
    Version: 6.3.0-ULTIMATE
    Requisitos: PowerShell 5.1+, Administrador
    Encoding: ASCII puro (maxima compatibilidad)
    Basado en: Fusion de v2.0.2, v3.0-OOP, v4.0, v5.0, v6.0, v6.2
#>

param(
    [switch]$DryRun,
    [string]$LogPath = "$env:TEMP\Autodesk-Nuke-v6.3_$(Get-Date -Format 'yyyyMMdd_HHmmss').log",
    [switch]$SkipValidation,
    [switch]$QuietMode
)

#Requires -Version 5.1
Set-StrictMode -Version 2.0
$ErrorActionPreference = "Continue"

# ================================================================================
# CONFIGURACION GLOBAL
# ================================================================================

$script:Config = @{
    LogFile           = $LogPath
    DryRun            = $DryRun
    QuietMode         = $QuietMode
    CleanupLevel      = $null
    MaxRetries        = 3
    RetryDelay        = 1500
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
    EnvVars           = 0
    Errors            = @()
    Warnings          = @()
    Skipped           = 0
}

$script:CleanupLevels = @{
    "BASIC"       = @{
        Name        = "Limpieza Basica"
        Description = "Procesos, servicios, MSI/ODIS/desinstaladores, HKLM, carpetas principales"
        Duration    = "3-5 minutos"
        Risk        = "Bajo"
    }
    "ADVANCED"    = @{
        Name        = "Limpieza Avanzada"
        Description = "BASIC + HKCU + AppData usuario actual + Temp + Common Files + FLEXnet"
        Duration    = "5-15 minutos"
        Risk        = "Medio"
    }
    "ENTERPRISE"  = @{
        Name        = "Limpieza Empresarial (NUCLEAR)"
        Description = "TODO: ADVANCED + TODOS los usuarios + tareas + variables entorno + registro fantasma"
        Duration    = "15-40 minutos"
        Risk        = "Alto - Irreversible"
    }
}

# ================================================================================
# FUNCIONES DE LOGGING Y SALIDA
# ================================================================================

function Initialize-Logging {
    $header = @"
================================================================================
Autodesk-Nuke v6.3 ULTIMATE - Para Casos Complejos
================================================================================
Inicio:       $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
Sistema:      Windows $([System.Environment]::OSVersion.VersionString)
PowerShell:   $($PSVersionTable.PSVersion)
Usuario:      $env:USERNAME | Maquina: $env:COMPUTERNAME
Modo:         $(if($script:Config.DryRun){'DRY-RUN (simulacion)'}else{'EJECUCION REAL'})
Nivel:        $($script:Config.CleanupLevel)
================================================================================
"@
    $header | Out-File $script:Config.LogFile -Encoding UTF8 -Force
    if (-not $script:Config.QuietMode) { Write-Host $header -ForegroundColor Cyan }
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
    if (-not $NoLog) { Add-Content -Path $script:Config.LogFile -Value $logEntry -Encoding UTF8 -ErrorAction SilentlyContinue }
    if (-not $script:Config.QuietMode -and -not $NoConsole) {
        $colors = @{ DEBUG = "Gray"; INFO = "Cyan"; SUCCESS = "Green"; WARNING = "Yellow"; ERROR = "Red" }
        Write-Host $logEntry -ForegroundColor $colors[$Level]
    }
    if ($Level -eq "ERROR") { $script:Stats.Errors += $Message }
    elseif ($Level -eq "WARNING") { $script:Stats.Warnings += $Message }
}

function Show-Banner {
    param([string]$Text, [string]$Color = "Cyan")
    $width = 80
    $line = "+" + ("-" * ($width - 2)) + "+"
    Write-Host "`n$line" -ForegroundColor $Color
    $padding = [math]::Max(0, [math]::Floor(($width - 2 - $Text.Length) / 2))
    Write-Host "| $((' ' * $padding))$Text$((' ' * ($width - 2 - $padding - $Text.Length))) |" -ForegroundColor $Color
    Write-Host "$line`n" -ForegroundColor $Color
}

function Show-Progress {
    param([int]$Current, [int]$Total, [string]$Activity)
    $percent = [math]::Min(($Current / $Total) * 100, 100)
    Write-Progress -Activity "Autodesk-Nuke v6.3 ULTIMATE" -Status $Activity -PercentComplete $percent -Id 0
}

# ================================================================================
# VALIDACIONES Y SELECCION
# ================================================================================

function Test-AdminPrivileges {
    $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object System.Security.Principal.WindowsPrincipal($identity)
    $isAdmin = $principal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $isAdmin) {
        Write-Host "[ERROR] Se requieren privilegios de Administrador." -ForegroundColor Red
        Write-Host "Ejecuta: powershell.exe -ExecutionPolicy Bypass -File `"$PSCommandPath`" -DryRun" -ForegroundColor Yellow
        exit 1
    }
    Write-LogOutput "[OK] Ejecutando con permisos de Administrador" -Level SUCCESS
}

function Select-CleanupLevel {
    Show-Banner "SELECCIONAR NIVEL DE LIMPIEZA" "Yellow"
    Write-Host "  La v6.3 esta disenada para los casos mas complejos." -ForegroundColor Gray
    Write-Host "  Para una limpieza rapida estandar, usa la v2.0.2.`n" -ForegroundColor Gray
    $i = 1
    $script:CleanupLevels.Keys | ForEach-Object {
        $info = $script:CleanupLevels[$_]
        Write-Host "  $i) $($info.Name)" -ForegroundColor Green
        Write-Host "     $($info.Description)" -ForegroundColor Gray
        Write-Host "     Duracion: $($info.Duration) | Riesgo: $($info.Risk)" -ForegroundColor Gray
        Write-Host ""
        $i++
    }
    $keys = @($script:CleanupLevels.Keys)
    do { $sel = Read-Host "Selecciona 1, 2 o 3" } while ($sel -match "[^1-3]" -or $sel -eq "")
    $script:Config.CleanupLevel = $keys[[int]$sel - 1]
    Write-LogOutput "Nivel seleccionado: $($script:Config.CleanupLevel)" -Level INFO
}

function Test-Prerequisites {
    if ($SkipValidation) { Write-LogOutput "Validaciones saltadas (SkipValidation)" -Level WARNING; return $true }
    Write-LogOutput "Validando prerequisitos del sistema..." -Level INFO

    $diskSpace = (Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DeviceID='C:'" -ErrorAction SilentlyContinue).FreeSpace / 1GB
    if ($diskSpace -lt 0.5) { Write-LogOutput "[CRITICO] Espacio en disco: ${diskSpace}GB" -Level ERROR; return $false }
    elseif ($diskSpace -lt 1) { Write-LogOutput "[AVISO] Espacio en disco bajo: ${diskSpace}GB" -Level WARNING }

    try {
        $av = Get-CimInstance -ClassName AntiVirusProduct -Namespace "root\SecurityCenter2" -ErrorAction SilentlyContinue
        if ($av) { Write-LogOutput "Antivirus detectado: puede ralentizar la limpieza" -Level INFO }
    } catch {}

    $found = Test-AutodeskPresence
    if (-not $found) {
        Write-LogOutput "[AVISO] No se detecto presencia de Autodesk" -Level WARNING
        $res = Read-Host "Continuar de todas formas? (S/N)"
        if ($res -ne "S") { exit 0 }
    }
    Write-LogOutput "[OK] Validaciones completadas" -Level SUCCESS
    return $true
}

function Test-AutodeskPresence {
    Write-LogOutput "Escaneando presencia de Autodesk..." -Level INFO
    $found = @()

    # Claves de registro directas (no tienen DisplayName, solo verificar existencia)
    $directKeys = @("HKLM:\SOFTWARE\Autodesk", "HKLM:\SOFTWARE\Wow6432Node\Autodesk")
    foreach ($key in $directKeys) {
        if (Test-Path $key) {
            Write-LogOutput "  [Registro] $key" -Level DEBUG
            $found += $key
        }
    }

    # Entradas de desinstalacion (estas SI tienen DisplayName)
    $uninstallPaths = @("HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*")
    try {
        $items = Get-ItemProperty $uninstallPaths -ErrorAction SilentlyContinue
        foreach ($item in $items) {
            $dn = $null
            try { $dn = $item.DisplayName } catch {}
            if ($dn -and $dn -match "Autodesk|AutoCAD|Revit|Inventor|Fusion|Civil|Maya|3ds") {
                $found += $item
                $dv = $null
                try { $dv = $item.DisplayVersion } catch {}
                Write-LogOutput "  [Producto] $dn v$dv" -Level DEBUG
            }
        }
    } catch {}

    # Directorios
    $dirs = @("C:\Program Files\Autodesk", "C:\Program Files (x86)\Autodesk", "C:\ProgramData\Autodesk")
    foreach ($dir in $dirs) { if (Test-Path $dir) { Write-LogOutput "  [Carpeta] $dir" -Level DEBUG; $found += $dir } }

    # Servicios
    $services = Get-Service -ErrorAction SilentlyContinue | Where-Object { $_.Name -match "Autodesk|Adsk|FlexNet|FNP" }
    foreach ($svc in $services) { Write-LogOutput "  [Servicio] $($svc.Name) ($($svc.Status))" -Level DEBUG; $found += $svc }

    if ($found.Count -gt 0) { Write-LogOutput "[OK] Detectados $($found.Count) elemento(s) de Autodesk" -Level SUCCESS }
    return ($found.Count -gt 0)
}

function Request-FinalConfirmation {
    Show-Banner "[CONFIRMACION FINAL]" "Yellow"
    if ($script:Config.DryRun) {
        Write-Host "Modo: DRY-RUN (sin cambios reales)" -ForegroundColor Green
        return $true
    }
    Write-Host "Esta accion es IRREVERSIBLE." -ForegroundColor Red
    Write-Host "Escribe exactamente: LIMPIAR $($script:Config.CleanupLevel)" -ForegroundColor Yellow
    $res = Read-Host "Confirmacion"
    if ($res -ne "LIMPIAR $($script:Config.CleanupLevel)") {
        Write-LogOutput "Confirmacion invalida. Operacion cancelada." -Level INFO
        exit 0
    }
    return $true
}

# ================================================================================
# OPERACIONES INTELIGENTES (con reintentos)
# ================================================================================

function Invoke-SafeOperation {
    param([string]$Description, [scriptblock]$Operation)
    $attempt = 0
    $success = $false
    while ($attempt -lt $script:Config.MaxRetries -and -not $success) {
        $attempt++
        try {
            if ($script:Config.DryRun) { Write-LogOutput "[DRY-RUN] $Description" -Level INFO; return $true }
            Write-LogOutput "Ejecutando: $Description" -Level DEBUG
            $null = & $Operation
            $success = $true
        }
        catch [System.IO.IOException] {
            if ($attempt -lt $script:Config.MaxRetries) {
                Write-LogOutput "Archivo bloqueado ($attempt/$($script:Config.MaxRetries)). Reintentando..." -Level WARNING
                Start-Sleep -Milliseconds $script:Config.RetryDelay
            }
            else {
                Write-LogOutput "[SKIP] No se pudo desbloquear: $Description" -Level WARNING
                $script:Stats.Skipped++
                return $false
            }
        }
        catch {
            if ($attempt -lt $script:Config.MaxRetries) {
                Start-Sleep -Milliseconds $script:Config.RetryDelay
            }
            else {
                Write-LogOutput "[ERROR] $Description - $($_.Exception.Message)" -Level WARNING
                $script:Stats.Skipped++
                return $false
            }
        }
    }
    if ($success) { Write-LogOutput "[OK] $Description" -Level SUCCESS }
    return $success
}

# ================================================================================
# PASO 1: DETENER PROCESOS Y SERVICIOS (Lista completa de v2.0.2 + v6.0)
# ================================================================================

function Stop-ProcessesAndServices {
    param([int]$Step, [int]$Total)
    Show-Progress $Step $Total "Deteniendo procesos y servicios..."
    Write-LogOutput "= PASO ${Step}: Deteniendo procesos y servicios" -Level INFO

    # Lista COMPLETA de procesos (fusionada de TODAS las versiones)
    $processes = @(
        "acad", "inventor", "revit", "fusion360", "civil3d", "maya", "3dsmax",
        "AutodeskAccess", "AdskIdentityManager", "AdSSO", "AdLM", "Node",
        "AdskLicensingService", "AdskLicensingAgent", "AdAppMgrSvc",
        "AutodeskDesktopApp", "AdODIS", "GenuineService",
        "AcEventSync", "AcQMod", "AdskAccessCore", "ADPClientService",
        "FNPLicensingService", "FNPLicensingService64", "LMgrd", "Adlmint",
        "Autodesk Access UI Host"
    )
    foreach ($name in $processes) {
        $procs = Get-Process -Name $name -ErrorAction SilentlyContinue
        foreach ($p in $procs) {
            Invoke-SafeOperation "Detener proceso: $($p.Name) (PID: $($p.Id))" -Operation {
                $p | Stop-Process -Force -ErrorAction Stop
            } | Out-Null
            $script:Stats.ProcessesStopped++
        }
    }

    # Lista COMPLETA de servicios (nombres exactos de v2.0.2 + deteccion dinamica)
    $staticServices = @(
        "AdskLicensingService", "AdAppMgrSvc",
        "AutodeskDesktopApp", "AutodeskDesktopAppService",
        "AGSService",
        "FlexNet Licensing Service", "FlexNet Licensing Service 64"
    )
    foreach ($svcName in $staticServices) {
        $svc = Get-Service -Name $svcName -ErrorAction SilentlyContinue
        if ($svc -and $svc.Status -eq 'Running') {
            Invoke-SafeOperation "Detener servicio (estatico): $svcName" -Operation {
                Stop-Service -Name $svcName -Force -ErrorAction Stop
            } | Out-Null
            $script:Stats.ServicesStopped++
        }
    }

    # Deteccion dinamica de servicios adicionales + kill forzado via CIM (v3-OOP)
    $dynServices = Get-Service -ErrorAction SilentlyContinue | Where-Object { $_.Name -match "Autodesk|Adsk|AdSSO" -and $_.Status -eq 'Running' }
    foreach ($s in $dynServices) {
        Invoke-SafeOperation "Detener servicio (dinamico): $($s.Name)" -Operation {
            Stop-Service -Name $s.Name -Force -ErrorAction Stop
            Start-Sleep -Milliseconds 500
            $cim = Get-CimInstance -ClassName Win32_Service -Filter "Name='$($s.Name)'" -ErrorAction SilentlyContinue
            if ($cim -and $cim.ProcessId -gt 0) {
                Stop-Process -Id $cim.ProcessId -Force -ErrorAction SilentlyContinue
            }
        } | Out-Null
        $script:Stats.ServicesStopped++
    }

    Write-LogOutput "Procesos: $($script:Stats.ProcessesStopped) | Servicios: $($script:Stats.ServicesStopped)" -Level INFO
}

# ================================================================================
# PASO 2: DESINSTALACION DE PAQUETES (Maxima cobertura)
# ================================================================================

function Uninstall-Packages {
    param([int]$Step, [int]$Total)
    Show-Progress $Step $Total "Desinstalando paquetes..."
    Write-LogOutput "= PASO ${Step}: Desinstalacion de paquetes (maxima cobertura)" -Level INFO

    # 2A. AdskUninstallHelper (Productos 2024+) - De v6.2
    $helperPath = "$env:ProgramData\Autodesk\Uninstallers"
    if (Test-Path $helperPath) {
        Write-LogOutput "  Buscando AdskUninstallHelper (2024+)..." -Level INFO
        $helpers = Get-ChildItem -Path $helperPath -Recurse -Filter "AdskUninstallHelper.exe" -ErrorAction SilentlyContinue
        foreach ($h in $helpers) {
            Invoke-SafeOperation "AdskUninstallHelper: $($h.Directory.Name)" -Operation {
                Start-Process -FilePath $h.FullName -Wait -NoNewWindow -ErrorAction Stop
            } | Out-Null
            $script:Stats.PackagesRemoved++
        }
    }

    # 2B. Desinstalador ODIS directo (RemoveODIS.exe) - De v2.0.2
    $odisUninstaller = "C:\Program Files\Autodesk\AdODIS\V1\RemoveODIS.exe"
    if (Test-Path $odisUninstaller) {
        Invoke-SafeOperation "Desinstalar ODIS (RemoveODIS.exe)" -Operation {
            Start-Process -FilePath $odisUninstaller -ArgumentList "-q" -Wait -NoNewWindow -ErrorAction Stop
        } | Out-Null
        $script:Stats.PackagesRemoved++
    }

    # 2C. Desinstalador AdskLicensing directo - De v2.0.2
    $licUninstaller = "C:\Program Files (x86)\Common Files\Autodesk Shared\AdskLicensing\uninstall.exe"
    if (Test-Path $licUninstaller) {
        Invoke-SafeOperation "Desinstalar Autodesk Licensing Service" -Operation {
            Start-Process -FilePath $licUninstaller -ArgumentList "--mode unattended" -Wait -NoNewWindow -ErrorAction Stop
        } | Out-Null
        $script:Stats.PackagesRemoved++
    }

    # 2D. Desinstalador Identity Manager directo - De v2.0.2
    $idUninstaller = "C:\Program Files\Autodesk\Autodesk Identity Manager\uninstall.exe"
    if (Test-Path $idUninstaller) {
        Invoke-SafeOperation "Desinstalar Autodesk Identity Manager" -Operation {
            Start-Process -FilePath $idUninstaller -ArgumentList "--mode unattended" -Wait -NoNewWindow -ErrorAction Stop
        } | Out-Null
        $script:Stats.PackagesRemoved++
    }

    # 2E. Paquetes MSI del registro - De v2.0.2/v6.0
    Write-LogOutput "  Buscando paquetes MSI registrados..." -Level INFO
    $regPaths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )
    $allItems = Get-ItemProperty $regPaths -ErrorAction SilentlyContinue
    $packages = @()
    foreach ($item in $allItems) {
        $dn = $null; $pub = $null; $us = $null
        try { $dn = $item.DisplayName } catch {}
        try { $pub = $item.Publisher } catch {}
        try { $us = $item.UninstallString } catch {}
        if (($dn -match "Autodesk" -or $pub -match "Autodesk") -and $us) { $packages += $item }
    }

    foreach ($pkg in $packages) {
        Write-LogOutput "  Detectado: $($pkg.DisplayName)" -Level DEBUG
        if ($pkg.UninstallString -match "msiexec") {
            $args = ($pkg.UninstallString -ireplace "msiexec.exe","" -ireplace "/I","/X") + " /quiet /qn /norestart"
            Invoke-SafeOperation "Desinstalar MSI: $($pkg.DisplayName)" -Operation {
                Start-Process "msiexec.exe" -ArgumentList $args -Wait -NoNewWindow -ErrorAction Stop
            } | Out-Null
            $script:Stats.PackagesRemoved++
        }
        elseif ($pkg.UninstallString -match "Installer.exe") {
            $exe = $pkg.UninstallString.Split("-")[0].Trim(' "')
            if (Test-Path $exe) {
                $mIndex = $pkg.UninstallString.IndexOf("-m")
                $extraArgs = if ($mIndex -gt 0) { $pkg.UninstallString.Substring($mIndex) } else { "" }
                Invoke-SafeOperation "Desinstalar ODIS: $($pkg.DisplayName)" -Operation {
                    Start-Process -FilePath $exe -ArgumentList "-q -i uninstall --trigger_point system $extraArgs" -Wait -NoNewWindow -ErrorAction Stop
                } | Out-Null
                $script:Stats.PackagesRemoved++
            }
        }
    }

    Write-LogOutput "Paquetes procesados: $($script:Stats.PackagesRemoved)" -Level INFO
}

# ================================================================================
# PASO 3: LIMPIEZA DE REGISTRO (Maxima profundidad)
# ================================================================================

function Clear-Registry {
    param([int]$Step, [int]$Total)
    Show-Progress $Step $Total "Limpiando registro..."
    Write-LogOutput "= PASO ${Step}: Limpieza de registro" -Level INFO
    $level = $script:Config.CleanupLevel

    # Claves principales HKLM + HKCR
    $keys = @("HKLM:\SOFTWARE\Autodesk", "HKLM:\SOFTWARE\Wow6432Node\Autodesk", "HKCR:\Autodesk")
    foreach ($k in $keys) {
        if (Test-Path $k) {
            Invoke-SafeOperation "Eliminar clave: $k" -Operation { Remove-Item -Path $k -Recurse -Force } | Out-Null
            $script:Stats.RegistryKeys++
        }
    }

    # Entradas fantasma en Uninstall (productos que ya no existen pero aparecen en Agregar/Quitar)
    $uninstallPaths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )
    $allUninstall = Get-ItemProperty $uninstallPaths -ErrorAction SilentlyContinue
    $phantoms = @()
    foreach ($item in $allUninstall) {
        $dn = $null
        try { $dn = $item.DisplayName } catch {}
        if ($dn -match "Autodesk|AutoCAD|Revit|Inventor") { $phantoms += $item }
    }
    foreach ($p in $phantoms) {
        Invoke-SafeOperation "Eliminar registro fantasma: $($p.DisplayName)" -Operation {
            Remove-Item -Path $p.PSPath -Recurse -Force
        } | Out-Null
        $script:Stats.RegistryKeys++
    }

    # Installer\Products (registro de instaladores Windows) - De v3-beta
    if ($level -eq "ENTERPRISE") {
        $prodPath = "HKLM:\SOFTWARE\Classes\Installer\Products\*"
        if (Test-Path $prodPath) {
            $allProds = Get-ItemProperty $prodPath -ErrorAction SilentlyContinue
            $prods = @()
            foreach ($item in $allProds) {
                $pn = $null
                try { $pn = $item.ProductName } catch {}
                if ($pn -match "Autodesk") { $prods += $item }
            }
            foreach ($prod in $prods) {
                Invoke-SafeOperation "Installer\Products: $($prod.ProductName)" -Operation {
                    Remove-Item -Path $prod.PSPath -Recurse -Force
                } | Out-Null
                $script:Stats.RegistryKeys++
            }
        }
    }

    Write-LogOutput "Claves de registro eliminadas: $($script:Stats.RegistryKeys)" -Level INFO
}

# ================================================================================
# PASO 4: ELIMINACION DE CARPETAS (Lista mas completa posible)
# ================================================================================

function Clear-Folders {
    param([int]$Step, [int]$Total)
    Show-Progress $Step $Total "Eliminando carpetas..."
    Write-LogOutput "= PASO ${Step}: Eliminacion de carpetas" -Level INFO
    $level = $script:Config.CleanupLevel

    # Carpetas principales (TODOS los niveles)
    $dirs = @(
        "C:\Autodesk",
        "C:\Program Files\Autodesk",
        "C:\Program Files (x86)\Autodesk",
        "C:\ProgramData\Autodesk"
    )

    # ADVANCED: agregar Common Files, FLEXnet, Public, Temp
    if ($level -eq "ADVANCED" -or $level -eq "ENTERPRISE") {
        $dirs += @(
            "$env:ProgramFiles\Common Files\Autodesk Shared",
            "${env:ProgramFiles(x86)}\Common Files\Autodesk Shared",
            "C:\Users\Public\Documents\Autodesk",
            "C:\Users\Public\Autodesk",
            "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Autodesk"
        )

        # FLEXnet: borrar solo archivos adsk* (para no afectar otras licencias)
        $flexNetPath = "$env:ProgramData\FLEXnet"
        if (Test-Path $flexNetPath) {
            Invoke-SafeOperation "Limpiar FLEXnet (archivos adsk*)" -Operation {
                Get-ChildItem -Path $flexNetPath -Filter "adsk*" -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction Stop
            } | Out-Null
        }

        # Temp: buscar carpetas Autodesk en TEMP (sin borrar TODO temp como hacia v2.0.2)
        $tempDirs = Get-ChildItem -Path $env:TEMP -Directory -Filter "*Autodesk*" -ErrorAction SilentlyContinue
        foreach ($td in $tempDirs) { $dirs += $td.FullName }

        # Windows Temp
        $winTempDirs = Get-ChildItem -Path "$env:WINDIR\Temp" -Directory -Filter "*Autodesk*" -ErrorAction SilentlyContinue
        foreach ($wtd in $winTempDirs) { $dirs += $wtd.FullName }
    }

    $dirs = $dirs | Select-Object -Unique
    foreach ($d in $dirs) {
        if (Test-Path $d) {
            Invoke-SafeOperation "Eliminar carpeta: $d" -Operation { Remove-Item -Path $d -Recurse -Force } | Out-Null
            $script:Stats.Folders++
        }
    }

    Write-LogOutput "Carpetas eliminadas: $($script:Stats.Folders)" -Level INFO
}

# ================================================================================
# PASO 5: PERFILES DE USUARIO (HKCU + AppData + Multi-usuario)
# ================================================================================

function Clear-UserProfiles {
    param([int]$Step, [int]$Total)
    $level = $script:Config.CleanupLevel
    if ($level -eq "BASIC") {
        Write-LogOutput "= PASO ${Step}: Perfiles de usuario (saltado por nivel BASIC)" -Level INFO
        return
    }

    Show-Progress $Step $Total "Limpiando perfiles de usuario..."
    Write-LogOutput "= PASO ${Step}: Limpieza de perfiles de usuario" -Level INFO

    # Usuario actual: HKCU
    if (Test-Path "HKCU:\Software\Autodesk") {
        Invoke-SafeOperation "Eliminar HKCU\Software\Autodesk" -Operation {
            Remove-Item "HKCU:\Software\Autodesk" -Recurse -Force
        } | Out-Null
    }

    # Usuario actual: AppData
    $userDirs = @("$env:LOCALAPPDATA\Autodesk", "$env:APPDATA\Autodesk")
    foreach ($ud in $userDirs) {
        if (Test-Path $ud) {
            Invoke-SafeOperation "Eliminar AppData: $ud" -Operation { Remove-Item $ud -Recurse -Force } | Out-Null
            $script:Stats.Folders++
        }
    }

    # Multi-usuario: cargar NTUSER.DAT de cada perfil (ENTERPRISE)
    if ($level -eq "ENTERPRISE") {
        Write-LogOutput "  Procesando perfiles de TODOS los usuarios..." -Level INFO
        $profiles = Get-ChildItem "C:\Users" -Directory -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -notmatch "^(Public|Default|Default User)" }

        foreach ($p in $profiles) {
            # AppData de otros usuarios
            $otherDirs = @(
                "$($p.FullName)\AppData\Local\Autodesk",
                "$($p.FullName)\AppData\Roaming\Autodesk"
            )
            foreach ($od in $otherDirs) {
                if (Test-Path $od) {
                    Invoke-SafeOperation "Eliminar AppData ($($p.Name)): $od" -Operation { Remove-Item $od -Recurse -Force } | Out-Null
                    $script:Stats.Folders++
                }
            }

            # NTUSER.DAT
            if ($p.Name -eq $env:USERNAME) { continue }
            $ntuser = Join-Path $p.FullName "NTUSER.DAT"
            if (Test-Path $ntuser) {
                $hive = "TEMP_$($p.Name)"
                Invoke-SafeOperation "Limpiar registro perfil: $($p.Name)" -Operation {
                    & cmd /c "reg load HKU\$hive `"$ntuser`"" 2>$null
                    if ($LASTEXITCODE -eq 0) {
                        try {
                            $regPath = "Registry::HKEY_USERS\$hive\Software\Autodesk"
                            if (Test-Path $regPath) { Remove-Item $regPath -Recurse -Force -ErrorAction Stop }
                        }
                        finally {
                            [gc]::Collect()
                            [gc]::WaitForPendingFinalizers()
                            Start-Sleep -Milliseconds 500
                            & cmd /c "reg unload HKU\$hive" 2>$null
                        }
                    }
                } | Out-Null
            }
        }
    }

    Write-LogOutput "Perfiles de usuario procesados" -Level INFO
}

# ================================================================================
# PASO 6: TAREAS PROGRAMADAS
# ================================================================================

function Remove-ScheduledTasks {
    param([int]$Step, [int]$Total)
    $level = $script:Config.CleanupLevel
    if ($level -eq "BASIC") {
        Write-LogOutput "= PASO ${Step}: Tareas programadas (saltado por nivel BASIC)" -Level INFO
        return
    }

    Show-Progress $Step $Total "Eliminando tareas programadas..."
    Write-LogOutput "= PASO ${Step}: Eliminacion de tareas programadas" -Level INFO

    # Por TaskPath
    $tasks = Get-ScheduledTask -TaskPath "\Autodesk*" -ErrorAction SilentlyContinue
    foreach ($t in $tasks) {
        Invoke-SafeOperation "Eliminar tarea (path): $($t.TaskName)" -Operation {
            Unregister-ScheduledTask -TaskName $t.TaskName -Confirm:$false -ErrorAction Stop
        } | Out-Null
        $script:Stats.Tasks++
    }

    # Por nombre (deteccion dinamica)
    $allTasks = Get-ScheduledTask -ErrorAction SilentlyContinue | Where-Object { $_.TaskName -match "Autodesk|Adsk" }
    foreach ($t in $allTasks) {
        Invoke-SafeOperation "Eliminar tarea (nombre): $($t.TaskName)" -Operation {
            Unregister-ScheduledTask -TaskName $t.TaskName -Confirm:$false -ErrorAction Stop
        } | Out-Null
        $script:Stats.Tasks++
    }

    Write-LogOutput "Tareas eliminadas: $($script:Stats.Tasks)" -Level INFO
}

# ================================================================================
# PASO 7: REPARACION DE BUCLES DE REINICIO (PendingFileRename + RebootRequired)
# ================================================================================

function Fix-RebootLoops {
    param([int]$Step, [int]$Total)
    Show-Progress $Step $Total "Reparando bucles de reinicio..."
    Write-LogOutput "= PASO ${Step}: Reparacion de bucles de reinicio" -Level INFO

    # 7A. PendingFileRenameOperations (filtrado inteligente, no borrado total - De v3-compact)
    $smPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager"
    try {
        $val = Get-ItemProperty -Path $smPath -Name "PendingFileRenameOperations" -ErrorAction SilentlyContinue
        if ($val.PendingFileRenameOperations) {
            $entries = $val.PendingFileRenameOperations
            $filtered = @()
            Write-LogOutput "  Analizando $($entries.Count) entradas PendingFileRename..." -Level DEBUG
            for ($i = 0; $i -lt $entries.Count; $i += 2) {
                if ($entries[$i] -notmatch "Autodesk|adsk|ADSK") {
                    $filtered += $entries[$i]
                    if ($i + 1 -lt $entries.Count) { $filtered += $entries[$i + 1] }
                }
            }
            $removed = [math]::Floor(($entries.Count - $filtered.Count) / 2)
            if ($removed -gt 0) {
                Write-LogOutput "  Removiendo $removed entradas de Autodesk de PendingFileRename" -Level INFO
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
    }
    catch { Write-LogOutput "[AVISO] Error procesando PendingFileRename: $($_.Exception.Message)" -Level WARNING }

    # 7B. RebootRequired (Windows Update) - Exclusivo de v2.0.2
    $rebootPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update"
    if (Test-Path "$rebootPath\RebootRequired") {
        Invoke-SafeOperation "Eliminar clave RebootRequired" -Operation {
            Remove-Item -Path "$rebootPath\RebootRequired" -Force -ErrorAction Stop
        } | Out-Null
        Write-LogOutput "  [OK] Clave RebootRequired eliminada" -Level SUCCESS
    }

    # 7C. Component Based Servicing (reboot pending) - Cobertura adicional
    $cbsPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending"
    if (Test-Path $cbsPath) {
        Write-LogOutput "  [INFO] CBS RebootPending detectado (no se modifica, es de Windows)" -Level INFO
    }

    Write-LogOutput "[OK] Bucles de reinicio mitigados" -Level SUCCESS
}

# ================================================================================
# PASO 8: VARIABLES DE ENTORNO (Enterprise)
# ================================================================================

function Clear-EnvironmentVariables {
    param([int]$Step, [int]$Total)
    $level = $script:Config.CleanupLevel
    if ($level -ne "ENTERPRISE") {
        Write-LogOutput "= PASO ${Step}: Variables de entorno (saltado, solo ENTERPRISE)" -Level INFO
        return
    }

    Show-Progress $Step $Total "Limpiando variables de entorno..."
    Write-LogOutput "= PASO ${Step}: Limpieza de variables de entorno" -Level INFO

    # PATH del sistema: remover entradas de Autodesk
    $sysPath = [System.Environment]::GetEnvironmentVariable("Path", "Machine")
    if ($sysPath) {
        $entries = $sysPath -split ";"
        $cleaned = $entries | Where-Object { $_ -notmatch "Autodesk|adsk" -and $_ -ne "" }
        $diff = $entries.Count - $cleaned.Count
        if ($diff -gt 0) {
            Invoke-SafeOperation "Limpiar PATH del sistema ($diff entradas)" -Operation {
                [System.Environment]::SetEnvironmentVariable("Path", ($cleaned -join ";"), "Machine")
            } | Out-Null
            $script:Stats.EnvVars += $diff
        }
    }

    # Variables especificas de Autodesk
    $envVars = @("ADSK_LICENSE_FILE", "AUTODESK_LICENSE_FILE", "FLEXLM_TIMEOUT")
    foreach ($var in $envVars) {
        $val = [System.Environment]::GetEnvironmentVariable($var, "Machine")
        if ($val) {
            Invoke-SafeOperation "Eliminar variable: $var" -Operation {
                [System.Environment]::SetEnvironmentVariable($var, $null, "Machine")
            } | Out-Null
            $script:Stats.EnvVars++
        }
    }

    Write-LogOutput "Variables de entorno limpiadas: $($script:Stats.EnvVars)" -Level INFO
}

# ================================================================================
# VERIFICACION POST-LIMPIEZA (Exhaustiva)
# ================================================================================

function Verify-CleanupCompletion {
    Write-LogOutput "= VERIFICACION POST-LIMPIEZA (exhaustiva)" -Level INFO
    $rem = @()

    if (Test-Path "HKLM:\SOFTWARE\Autodesk") { $rem += "Clave HKLM\SOFTWARE\Autodesk" }
    if (Test-Path "HKLM:\SOFTWARE\Wow6432Node\Autodesk") { $rem += "Clave HKLM\Wow6432Node\Autodesk" }
    if (Test-Path "HKCR:\Autodesk") { $rem += "Clave HKCR\Autodesk" }
    if (Test-Path "C:\Program Files\Autodesk") { $rem += "Carpeta C:\Program Files\Autodesk" }
    if (Test-Path "C:\Program Files (x86)\Autodesk") { $rem += "Carpeta C:\Program Files (x86)\Autodesk" }
    if (Test-Path "C:\ProgramData\Autodesk") { $rem += "Carpeta C:\ProgramData\Autodesk" }

    $svcs = Get-Service -ErrorAction SilentlyContinue | Where-Object { $_.Name -match "Autodesk|Adsk" }
    if ($svcs) { $rem += "Servicios activos: $($svcs.Name -join ', ')" }

    $procs = Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.Name -match "Autodesk|Adsk|acad|inventor|revit" }
    if ($procs) { $rem += "Procesos activos: $($procs.Name -join ', ')" }

    # Verificar entradas fantasma restantes
    $verifyItems = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*" -ErrorAction SilentlyContinue
    $phantomCount = 0
    foreach ($vi in $verifyItems) {
        $dn = $null
        try { $dn = $vi.DisplayName } catch {}
        if ($dn -match "Autodesk") { $phantomCount++ }
    }
    if ($phantomCount -gt 0) { $rem += "Entradas fantasma en Agregar/Quitar: $phantomCount" }

    if ($rem.Count -gt 0) {
        Write-LogOutput "[!] Detectados $($rem.Count) restos:" -Level WARNING
        foreach ($r in $rem) { Write-LogOutput "  - $r" -Level WARNING }
        return $false
    }

    Write-LogOutput "[OK] Limpieza verificada exitosamente - Sistema limpio" -Level SUCCESS
    return $true
}

# ================================================================================
# EJECUCION PRINCIPAL
# ================================================================================

try {
    Clear-Host
    Show-Banner "AUTODESK-NUKE v6.3 ULTIMATE" "Cyan"
    Write-Host "  Disenada para los casos mas complejos y problematicos." -ForegroundColor Gray
    Write-Host "  Para limpieza estandar, usa la v2.0.2.`n" -ForegroundColor Gray

    Test-AdminPrivileges
    Select-CleanupLevel
    Initialize-Logging

    if (-not (Test-Prerequisites)) {
        Write-LogOutput "Validacion fallida. Abortando." -Level ERROR
        exit 1
    }
    Request-FinalConfirmation | Out-Null

    # Limpieza en 8 pasos
    $steps = 8
    $curr = 1

    Stop-ProcessesAndServices $curr $steps; $curr++
    Uninstall-Packages $curr $steps; $curr++
    Clear-Registry $curr $steps; $curr++
    Clear-Folders $curr $steps; $curr++
    Clear-UserProfiles $curr $steps; $curr++
    Remove-ScheduledTasks $curr $steps; $curr++
    Fix-RebootLoops $curr $steps; $curr++
    Clear-EnvironmentVariables $curr $steps; $curr++

    Show-Progress $steps $steps "Finalizando..."
    Write-Progress -Activity "Autodesk-Nuke v6.3 ULTIMATE" -Completed
    $ok = Verify-CleanupCompletion

    # Reporte final
    $script:Config.EndTime = Get-Date
    $dur = ($script:Config.EndTime - $script:Config.StartTime).TotalSeconds

    Show-Banner "REPORTE FINAL" "Green"
    $rep = @"
+------------------------------------------------------------------------------+
|                  AUTODESK-NUKE v6.3 ULTIMATE - ESTADISTICAS                |
+------------------------------------------------------------------------------+
Procesos detenidos:        $($script:Stats.ProcessesStopped)
Servicios detenidos:       $($script:Stats.ServicesStopped)
Paquetes desinstalados:    $($script:Stats.PackagesRemoved)
Claves de registro:        $($script:Stats.RegistryKeys)
Carpetas eliminadas:       $($script:Stats.Folders)
Tareas programadas:        $($script:Stats.Tasks)
Variables de entorno:      $($script:Stats.EnvVars)
Elementos saltados:        $($script:Stats.Skipped)

Duracion total:            $([math]::Round($dur, 2))s
Errores encontrados:       $($script:Stats.Errors.Count)
Advertencias:              $($script:Stats.Warnings.Count)

Verificacion:              $(if($ok){'[OK] EXITOSA - SISTEMA LIMPIO'}else{'[!] INCOMPLETA - Ver restos arriba'})
Log:                       $($script:Config.LogFile)
+------------------------------------------------------------------------------+
"@
    Write-Host $rep -ForegroundColor Green
    $rep | Out-File $script:Config.LogFile -Append -Encoding UTF8

    if ($script:Stats.Errors.Count -gt 0) {
        Write-Host "`nERRORES ENCONTRADOS:" -ForegroundColor Red
        $script:Stats.Errors | ForEach-Object { Write-Host "  [ERROR] $_" -ForegroundColor Red }
    }
    if ($script:Stats.Warnings.Count -gt 0) {
        Write-Host "`nADVERTENCIAS:" -ForegroundColor Yellow
        $script:Stats.Warnings | ForEach-Object { Write-Host "  [AVISO] $_" -ForegroundColor Yellow }
    }

    Write-LogOutput "================================================================================" -Level SUCCESS
    Write-LogOutput "[OK] OPERACION COMPLETADA" -Level SUCCESS
    Write-LogOutput "================================================================================" -Level SUCCESS

    if (-not $script:Config.DryRun) {
        Write-Host "`n[IMPORTANTE] Se recomienda REINICIAR el equipo antes de reinstalar Autodesk." -ForegroundColor Yellow
    }
}
catch {
    Write-LogOutput "[ERROR CRITICO] $($_.Exception.Message)" -Level ERROR
    Write-LogOutput "Stack Trace: $($_.ScriptStackTrace)" -Level DEBUG
    exit 1
}
