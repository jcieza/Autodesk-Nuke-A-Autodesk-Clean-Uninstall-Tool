<#
.SYNOPSIS
    Version mejorada: 3.0.0 (Compact Edition)
.DESCRIPTION
    Script de limpieza Autodesk modificado para evitar daños a operaciones del sistema.
#>
param ([switch]$AllUsers)
$ErrorActionPreference = "Continue"
$LogPath = "$env:TEMP\Autodesk-Nuke-Compact.log"
if(Test-Path $LogPath){Remove-Item $LogPath -Force -ErrorAction SilentlyContinue}

function Write-Log([string]$Msg, [string]$Lvl="INFO"){
    Add-Content $LogPath "[$((Get-Date).ToString('HH:mm:ss'))] [$Lvl] $Msg"
    Write-Host "[$Lvl] $Msg"
}

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.BuiltInRole]::Administrator)
if(-not $isAdmin){
    Write-Host "Ejecuta como Administrador."
    exit
}

function Stop-AutodeskServices {
    Write-Log "Deteniendo procesos..." "INFO"
    "AutodeskAccess", "AdskIdentityManager", "AdSSO", "Node" | ForEach-Object { Get-Process $_ -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue }
    Get-Service | Where-Object { $_.Name -match "Autodesk" -or $_.DisplayName -match "Autodesk" } | ForEach-Object {
        Stop-Service $_.Name -Force -ErrorAction SilentlyContinue
        if ((Get-Service $_.Name).Status -ne 'Stopped') {
            $cim = Get-CimInstance Win32_Service -Filter "Name='$($_.Name)'" -ErrorAction SilentlyContinue
            if ($cim.ProcessId) { Stop-Process -Id $cim.ProcessId -Force -ErrorAction SilentlyContinue }
        }
    }
}

function Remove-AutodeskDirs {
    Write-Log "Borrando carpetas..."
    $dirs = @("C:\Program Files\Autodesk", "C:\Program Files (x86)\Autodesk", "C:\ProgramData\Autodesk", "$env:ProgramData\FLEXnet\adsk*")
    $dirs | Where-Object { Test-Path $_ } | ForEach-Object { Remove-Item $_ -Recurse -Force -ErrorAction SilentlyContinue }
}

function Fix-RebootLoops {
    Write-Log "Fixing Reboot Loops safely..."
    $path = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager"
    $val = Get-ItemProperty $path -Name "PendingFileRenameOperations" -ErrorAction SilentlyContinue
    if($val.PendingFileRenameOperations){
        $arr = $val.PendingFileRenameOperations
        $new = @()
        for($i=0; $i -lt $arr.Count; $i+=2){
            if($arr[$i] -notmatch "Autodesk|adsk"){
                $new += $arr[$i]
                if($i+1 -lt $arr.Count){ $new += $arr[$i+1] }
            }
        }
        Set-ItemProperty $path "PendingFileRenameOperations" $new -Type MultiString -Force
    }
}

Stop-AutodeskServices; Remove-AutodeskDirs; Fix-RebootLoops
Write-Log "Finalizado." "SUCCESS"
