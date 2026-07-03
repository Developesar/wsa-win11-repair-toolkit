[CmdletBinding()]
param(
    [switch]$All,
    [switch]$AddManifestCapability,
    [switch]$ApplyCrashPatch,
    [switch]$SetHighPerformanceGpu,
    [switch]$DisableLocalNetworkAccess,
    [switch]$RefreshHns,
    [switch]$LaunchPlayStore,
    [switch]$Verify,
    [string]$BackupRoot = ''
)

$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false
$PackageName = 'MicrosoftCorporationII.WindowsSubsystemForAndroid'
$PackageFamily = 'MicrosoftCorporationII.WindowsSubsystemForAndroid_8wekyb3d8bbwe'
$Script:ScriptRoot = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
if ([string]::IsNullOrWhiteSpace($BackupRoot)) {
    $BackupRoot = Join-Path $Script:ScriptRoot '..\backups'
}
$Script:StartedAt = Get-Date
$Script:RunId = Get-Date -Format 'yyyyMMdd-HHmmss'
$Script:LogDir = Join-Path $Script:ScriptRoot '..\logs'
$Script:LogPath = Join-Path $Script:LogDir "repair-$Script:RunId.log"
$Script:BackupDir = Join-Path $BackupRoot $Script:RunId

if ($All) {
    $AddManifestCapability = $true
    $ApplyCrashPatch = $true
    $SetHighPerformanceGpu = $true
    $DisableLocalNetworkAccess = $true
    $RefreshHns = $true
    $LaunchPlayStore = $true
    $Verify = $true
}

function Write-Log {
    param([string]$Message)

    $line = '{0} {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Message
    Write-Host $line
    Add-Content -LiteralPath $Script:LogPath -Value $line -Encoding UTF8
}

function Test-IsAdmin {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Show-Usage {
    @'
Usage:
  PowerShell (Run as Administrator)
  .\scripts\Repair-WSAWin11.ps1 -All

Safer staged usage:
  .\scripts\Repair-WSAWin11.ps1 -SetHighPerformanceGpu -DisableLocalNetworkAccess -RefreshHns -LaunchPlayStore -Verify
  .\scripts\Repair-WSAWin11.ps1 -ApplyCrashPatch

Notes:
  -All applies the app-uri crash patch, GPU preference, compatible NAT networking, HNS refresh, launch, and verification.
  Backups are written under .\backups\<timestamp>.
  Logs are written under .\logs.
'@ | Write-Host
}

function Get-WsaPackageInfo {
    $pkg = Get-AppxPackage -Name $PackageName -ErrorAction SilentlyContinue
    if (-not $pkg) {
        throw "WSA package was not found: $PackageName"
    }
    if (-not (Test-Path -LiteralPath $pkg.InstallLocation)) {
        throw "WSA install location does not exist: $($pkg.InstallLocation)"
    }
    return $pkg
}

function Stop-WsaProcesses {
    foreach ($name in 'WsaClient','WsaSettings','WsaService','WSACrashUploader','vmmemWSA') {
        Get-Process -Name $name -ErrorAction SilentlyContinue | ForEach-Object {
            Write-Log "Stopping process: $($_.Name) $($_.Id)"
            Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue
        }
    }
    Start-Sleep -Seconds 2
}

function Find-Bytes {
    param(
        [byte[]]$Haystack,
        [byte[]]$Needle
    )

    for ($i = 0; $i -le $Haystack.Length - $Needle.Length; $i++) {
        $matched = $true
        for ($j = 0; $j -lt $Needle.Length; $j++) {
            if ($Haystack[$i + $j] -ne $Needle[$j]) {
                $matched = $false
                break
            }
        }
        if ($matched) {
            return $i
        }
    }
    return -1
}

function Backup-File {
    param(
        [string]$Path,
        [string]$Label
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Backup source not found: $Path"
    }
    $extension = [IO.Path]::GetExtension($Path)
    $fileName = if ($extension) { "$Label$extension" } else { $Label }
    $destination = Join-Path $Script:BackupDir $fileName
    Copy-Item -LiteralPath $Path -Destination $destination -Force
    Write-Log "Backup created: $destination"
    return $destination
}

function Add-RestrictedAppUriCapability {
    param([string]$InstallLocation)

    $manifest = Join-Path $InstallLocation 'AppxManifest.xml'
    if (-not (Test-Path -LiteralPath $manifest)) {
        throw "AppxManifest.xml not found: $manifest"
    }

    $text = Get-Content -LiteralPath $manifest -Raw
    if ($text -match 'restrictedAppUriHandlerHost') {
        Write-Log 'Manifest already has restrictedAppUriHandlerHost.'
    }
    else {
        if ($text -notmatch 'xmlns:rescap=') {
            throw 'Manifest has no rescap namespace; refusing to edit automatically.'
        }
        if ($text -notmatch '</Capabilities>') {
            throw 'Manifest has no </Capabilities> section; refusing to edit automatically.'
        }

        Backup-File -Path $manifest -Label 'AppxManifest.before-appuri-fix' | Out-Null
        $insert = '    <rescap:Capability Name="restrictedAppUriHandlerHost" />'
        $text = $text -replace '(?m)^(\s*</Capabilities>)', "$insert`r`n`$1"
        Set-Content -LiteralPath $manifest -Value $text -Encoding UTF8
        Write-Log 'Added restrictedAppUriHandlerHost to manifest.'
    }

    Write-Log "Registering manifest: $manifest"
    Add-AppxPackage -ForceApplicationShutdown -ForceUpdateFromAnyVersion -Register $manifest
    Write-Log 'Manifest registration completed.'
}

function Apply-WsaClientCrashPatch {
    param([string]$InstallLocation)

    $exe = Join-Path $InstallLocation 'WsaClient\WsaClient.exe'
    if (-not (Test-Path -LiteralPath $exe)) {
        throw "WsaClient.exe not found: $exe"
    }

    Backup-File -Path $exe -Label 'WsaClient.before-crash-patch' | Out-Null
    $bytes = [System.IO.File]::ReadAllBytes($exe)
    $changed = $false

    $patch1Original = [byte[]](0x81, 0xFB, 0x05, 0x00, 0x07, 0x80, 0x75, 0x19)
    $patch1Patched = [byte[]](0x81, 0xFB, 0x05, 0x00, 0x07, 0x80, 0xEB, 0x19)
    $patch1Index = Find-Bytes -Haystack $bytes -Needle $patch1Original
    if ($patch1Index -ge 0) {
        $bytes[$patch1Index + 6] = 0xEB
        $changed = $true
        Write-Log ("Patch1 applied at file offset 0x{0:X}" -f ($patch1Index + 6))
    }
    elseif ((Find-Bytes -Haystack $bytes -Needle $patch1Patched) -ge 0) {
        Write-Log 'Patch1 already applied.'
    }
    else {
        throw 'Patch1 anchor not found. This WsaClient.exe does not match the known layout.'
    }

    $patch2Original = [byte[]](0x85, 0xC0, 0x78, 0x26, 0x48, 0x8B, 0x4D)
    $patch2Patched = [byte[]](0x85, 0xC0, 0x90, 0x90, 0x48, 0x8B, 0x4D)
    $patch2Index = Find-Bytes -Haystack $bytes -Needle $patch2Original
    if ($patch2Index -ge 0) {
        $bytes[$patch2Index + 2] = 0x90
        $bytes[$patch2Index + 3] = 0x90
        $changed = $true
        Write-Log ("Patch2 applied at file offset 0x{0:X}" -f ($patch2Index + 2))
    }
    elseif ((Find-Bytes -Haystack $bytes -Needle $patch2Patched) -ge 0) {
        Write-Log 'Patch2 already applied.'
    }
    else {
        throw 'Patch2 anchor not found. This WsaClient.exe does not match the known layout.'
    }

    if ($changed) {
        [System.IO.File]::WriteAllBytes($exe, $bytes)
        Write-Log 'Patched WsaClient.exe written.'
    }
    else {
        Write-Log 'No WsaClient.exe binary changes were needed.'
    }

    $hash = Get-FileHash -Algorithm SHA256 -LiteralPath $exe
    Write-Log "WsaClient.exe SHA256: $($hash.Hash)"
}

function Set-WsaHighPerformanceGpu {
    param([string]$InstallLocation)

    $exe = Join-Path $InstallLocation 'WsaClient\WsaClient.exe'
    if (-not (Test-Path -LiteralPath $exe)) {
        throw "WsaClient.exe not found: $exe"
    }

    $key = 'HKCU:\Software\Microsoft\DirectX\UserGpuPreferences'
    New-Item -Path $key -Force | Out-Null
    Set-ItemProperty -Path $key -Name $exe -Value 'GpuPreference=2;' -Type String
    Write-Log "Windows GPU preference set: $exe = GpuPreference=2;"
}

function Set-WsaLocalNetworkAccess {
    param([bool]$Enabled)

    $settingsPath = Join-Path $env:LOCALAPPDATA "Packages\$PackageFamily\Settings\settings.dat"
    if (-not (Test-Path -LiteralPath $settingsPath)) {
        throw "WSA settings hive not found: $settingsPath"
    }

    $mountName = 'HKU\WSAFixTemp'
    $mountKeyForRegFile = '[HKEY_USERS\WSAFixTemp\LocalState]'
    $stateBackup = Join-Path $Script:BackupDir 'wsa-localstate-before.reg'
    $tempReg = Join-Path $env:TEMP "wsa-localnetwork-$Script:RunId.reg"

    & cmd.exe /c "reg unload $mountName >nul 2>nul & exit /b 0" | Out-Null
    try {
        $loadOutput = & reg.exe load $mountName $settingsPath 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw "reg load failed: $loadOutput"
        }

        & reg.exe export "$mountName\LocalState" $stateBackup /y | Out-Null
        if ($LASTEXITCODE -ne 0) {
            throw "reg export failed with exit code $LASTEXITCODE"
        }
        Write-Log "LocalState backup created: $stateBackup"

        $backupText = Get-Content -LiteralPath $stateBackup -Raw
        $line = [regex]::Match($backupText, '(?m)^"LocalNetworkAccessEnabled"=hex\([^)]+\):[^\r\n]*(?:\r?\n\s+[^\r\n]*)*').Value
        if (-not $line) {
            throw 'LocalNetworkAccessEnabled was not found in WSA LocalState.'
        }

        $firstByte = if ($Enabled) { '01' } else { '00' }
        $updatedLine = $line -replace '(:)[0-9a-fA-F]{2},', "`$1$firstByte,"
        @(
            'Windows Registry Editor Version 5.00'
            ''
            $mountKeyForRegFile
            $updatedLine
        ) | Set-Content -LiteralPath $tempReg -Encoding Unicode

        & reg.exe import $tempReg | Out-Null
        if ($LASTEXITCODE -ne 0) {
            throw "reg import failed with exit code $LASTEXITCODE"
        }

        $state = if ($Enabled) { 'enabled' } else { 'disabled' }
        Write-Log "LocalNetworkAccessEnabled $state while preserving the original registry value type."
    }
    finally {
        & cmd.exe /c "reg unload $mountName >nul 2>nul & exit /b 0" | Out-Null
        Remove-Item -LiteralPath $tempReg -Force -ErrorAction SilentlyContinue
    }
}

function Refresh-WsaHostNetworking {
    foreach ($serviceName in 'hns','vmcompute','iphlpsvc') {
        $svc = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
        if (-not $svc) {
            Write-Log "Service not found: $serviceName"
            continue
        }
        try {
            Write-Log "Restarting service: $serviceName (was $($svc.Status))"
            Restart-Service -Name $serviceName -Force -ErrorAction Stop
            Start-Sleep -Seconds 2
            Write-Log "Service status: $serviceName = $((Get-Service -Name $serviceName).Status)"
        }
        catch {
            Write-Log "Service restart failed: $serviceName = $($_.Exception.Message)"
        }
    }

    try {
        ipconfig /flushdns | ForEach-Object { Write-Log $_ }
    }
    catch {
        Write-Log "ipconfig /flushdns failed: $($_.Exception.Message)"
    }
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

function Test-WsaNetworking {
    $adb = Get-AdbPath
    if (-not $adb) {
        Write-Log 'adb.exe was not found; skipping ADB verification.'
        return
    }

    Write-Log "Using adb: $adb"
    & $adb connect 127.0.0.1:58526 2>&1 | ForEach-Object { Write-Log "adb: $_" }
    & $adb devices 2>&1 | ForEach-Object { Write-Log "adb: $_" }
    & $adb shell ip addr show eth0 2>&1 | ForEach-Object { Write-Log "eth0: $_" }
    & $adb shell ip route show table 1002 2>&1 | ForEach-Object { Write-Log "route1002: $_" }
    & $adb shell ping -c 1 -W 3 8.8.8.8 2>&1 | ForEach-Object { Write-Log "ping-ip: $_" }
    & $adb shell ping -c 1 -W 3 google.com 2>&1 | ForEach-Object { Write-Log "ping-dns: $_" }
    & $adb shell ping -c 1 -W 3 accounts.google.com 2>&1 | ForEach-Object { Write-Log "ping-google-auth: $_" }
}

if (-not ($AddManifestCapability -or $ApplyCrashPatch -or $SetHighPerformanceGpu -or $DisableLocalNetworkAccess -or $RefreshHns -or $LaunchPlayStore -or $Verify)) {
    Show-Usage
    exit 0
}

New-Item -ItemType Directory -Path $Script:LogDir,$Script:BackupDir -Force | Out-Null
"WSA repair started: $(Get-Date -Format o)" | Set-Content -LiteralPath $Script:LogPath -Encoding UTF8
Write-Log "Running as admin: $(Test-IsAdmin)"

if (-not (Test-IsAdmin)) {
    throw 'Run this script from an elevated PowerShell window.'
}

$pkg = Get-WsaPackageInfo
Write-Log "Package: $($pkg.PackageFullName)"
Write-Log "InstallLocation: $($pkg.InstallLocation)"
Write-Log "IsDevelopmentMode: $($pkg.IsDevelopmentMode)"
Write-Log "SignatureKind: $($pkg.SignatureKind)"

if ($AddManifestCapability -or $ApplyCrashPatch -or $DisableLocalNetworkAccess -or $RefreshHns) {
    Stop-WsaProcesses
}

if ($AddManifestCapability) {
    Add-RestrictedAppUriCapability -InstallLocation $pkg.InstallLocation
}
if ($ApplyCrashPatch) {
    Apply-WsaClientCrashPatch -InstallLocation $pkg.InstallLocation
}
if ($SetHighPerformanceGpu) {
    Set-WsaHighPerformanceGpu -InstallLocation $pkg.InstallLocation
}
if ($DisableLocalNetworkAccess) {
    Set-WsaLocalNetworkAccess -Enabled:$false
}
if ($RefreshHns) {
    Refresh-WsaHostNetworking
}
if ($LaunchPlayStore) {
    Write-Log 'Launching Play Store via wsa://com.android.vending'
    Start-Process 'wsa://com.android.vending'
    Start-Sleep -Seconds 30
}
if ($Verify) {
    Test-WsaNetworking
    Get-WinEvent -FilterHashtable @{ LogName = 'Application'; StartTime = $Script:StartedAt } -ErrorAction SilentlyContinue |
        Where-Object { $_.Message -match 'WsaClient|WindowsSubsystemForAndroid|MoAppCrash|MoBEX' } |
        ForEach-Object { Write-Log "EventLog: $($_.TimeCreated) $($_.ProviderName) $($_.Id)" }
}

Write-Log 'WSA repair finished.'
