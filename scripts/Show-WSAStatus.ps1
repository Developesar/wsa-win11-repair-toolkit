[CmdletBinding()]
param()

$ErrorActionPreference = 'Continue'
$PackageName = 'MicrosoftCorporationII.WindowsSubsystemForAndroid'
$PackageFamily = 'MicrosoftCorporationII.WindowsSubsystemForAndroid_8wekyb3d8bbwe'

function Section {
    param([string]$Title)
    Write-Host ''
    Write-Host "== $Title =="
}

function Get-AdbPath {
    $cmd = Get-Command adb.exe -ErrorAction SilentlyContinue
    if ($cmd) {
        return $cmd.Source
    }

    $local = Join-Path $env:LOCALAPPDATA 'Android\Sdk\platform-tools\adb.exe'
    if (Test-Path -LiteralPath $local) {
        return $local
    }

    return $null
}

Section 'WSA package'
$pkg = Get-AppxPackage -Name $PackageName -ErrorAction SilentlyContinue
if ($pkg) {
    $pkg | Select-Object Name,PackageFullName,Version,InstallLocation,IsDevelopmentMode,SignatureKind,Status | Format-List
}
else {
    Write-Host "Package not found: $PackageName"
}

Section 'WSA processes'
Get-Process -Name WsaClient,WsaSettings,WsaService,WSACrashUploader,vmmemWSA -ErrorAction SilentlyContinue |
    Select-Object Name,Id,CPU,Path |
    Format-Table -AutoSize

Section 'GPU preference'
$gpuKey = 'HKCU:\Software\Microsoft\DirectX\UserGpuPreferences'
if ($pkg -and (Test-Path $gpuKey)) {
    $wsaClient = Join-Path $pkg.InstallLocation 'WsaClient\WsaClient.exe'
    $value = (Get-ItemProperty -Path $gpuKey -ErrorAction SilentlyContinue).$wsaClient
    Write-Host "$wsaClient = $value"
}
else {
    Write-Host 'No GPU preference found.'
}

Section 'Recent WSA crash events'
Get-WinEvent -FilterHashtable @{ LogName = 'Application'; StartTime = (Get-Date).AddHours(-12) } -ErrorAction SilentlyContinue |
    Where-Object { $_.Message -match 'WsaClient|WindowsSubsystemForAndroid|MoAppCrash|MoBEX' } |
    Select-Object TimeCreated,ProviderName,Id,LevelDisplayName |
    Format-Table -AutoSize

Section 'ADB network'
$adb = Get-AdbPath
if (-not $adb) {
    Write-Host 'adb.exe not found.'
}
else {
    Write-Host "adb: $adb"
    & $adb connect 127.0.0.1:58526
    & $adb devices
    & $adb shell ip addr show eth0
    & $adb shell ip route show table 1002
    & $adb shell ping -c 1 -W 3 google.com
}

Section 'WSA settings hive'
$settingsPath = Join-Path $env:LOCALAPPDATA "Packages\$PackageFamily\Settings\settings.dat"
if (Test-Path -LiteralPath $settingsPath) {
    Write-Host "settings.dat: $settingsPath"
    Write-Host 'To inspect LocalNetworkAccessEnabled exactly, run Repair-WSAWin11.ps1 from an elevated PowerShell window or export the hive manually.'
}
else {
    Write-Host "settings.dat not found: $settingsPath"
}
