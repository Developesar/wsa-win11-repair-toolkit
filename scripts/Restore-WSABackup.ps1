[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$BackupDirectory
)

$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false
$PackageName = 'MicrosoftCorporationII.WindowsSubsystemForAndroid'
$PackageFamily = 'MicrosoftCorporationII.WindowsSubsystemForAndroid_8wekyb3d8bbwe'

function Test-IsAdmin {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Test-IsAdmin)) {
    throw 'Run this script from an elevated PowerShell window.'
}
if (-not (Test-Path -LiteralPath $BackupDirectory)) {
    throw "Backup directory not found: $BackupDirectory"
}

$pkg = Get-AppxPackage -Name $PackageName -ErrorAction SilentlyContinue
if (-not $pkg) {
    throw "WSA package was not found: $PackageName"
}

foreach ($name in 'WsaClient','WsaSettings','WsaService','WSACrashUploader','vmmemWSA') {
    Get-Process -Name $name -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
}
Start-Sleep -Seconds 2

$manifestBackup = Get-ChildItem -LiteralPath $BackupDirectory -Filter 'AppxManifest.before-appuri-fix.xml' -ErrorAction SilentlyContinue | Select-Object -First 1
if ($manifestBackup) {
    $manifestPath = Join-Path $pkg.InstallLocation 'AppxManifest.xml'
    Copy-Item -LiteralPath $manifestBackup.FullName -Destination $manifestPath -Force
    Add-AppxPackage -ForceApplicationShutdown -ForceUpdateFromAnyVersion -Register $manifestPath
    Write-Host "Restored manifest: $manifestPath"
}

$clientBackup = Get-ChildItem -LiteralPath $BackupDirectory -Filter 'WsaClient.before-crash-patch.exe' -ErrorAction SilentlyContinue | Select-Object -First 1
if ($clientBackup) {
    $clientPath = Join-Path $pkg.InstallLocation 'WsaClient\WsaClient.exe'
    Copy-Item -LiteralPath $clientBackup.FullName -Destination $clientPath -Force
    Write-Host "Restored WsaClient.exe: $clientPath"
}

$localStateBackup = Get-ChildItem -LiteralPath $BackupDirectory -Filter 'wsa-localstate-before.reg' -ErrorAction SilentlyContinue | Select-Object -First 1
if ($localStateBackup) {
    $settingsPath = Join-Path $env:LOCALAPPDATA "Packages\$PackageFamily\Settings\settings.dat"
    if (-not (Test-Path -LiteralPath $settingsPath)) {
        throw "WSA settings hive not found: $settingsPath"
    }

    $mountName = 'HKU\WSARestoreTemp'
    & cmd.exe /c "reg unload $mountName >nul 2>nul & exit /b 0" | Out-Null
    try {
        $loadOutput = & reg.exe load $mountName $settingsPath 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw "reg load failed: $loadOutput"
        }

        $restoreReg = Join-Path $env:TEMP "wsa-restore-localstate-$(Get-Date -Format yyyyMMddHHmmss).reg"
        $text = Get-Content -LiteralPath $localStateBackup.FullName -Raw
        $text = $text -replace '\[HKEY_USERS\\WSAFixTemp\\LocalState\]', '[HKEY_USERS\WSARestoreTemp\LocalState]'
        $text = $text -replace '\[HKEY_USERS\\WSAAdvancedCodex\\LocalState\]', '[HKEY_USERS\WSARestoreTemp\LocalState]'
        $text = $text -replace '\[HKEY_USERS\\WSATempCodex\\LocalState\]', '[HKEY_USERS\WSARestoreTemp\LocalState]'
        Set-Content -LiteralPath $restoreReg -Value $text -Encoding Unicode

        & reg.exe import $restoreReg | Out-Null
        if ($LASTEXITCODE -ne 0) {
            throw "reg import failed with exit code $LASTEXITCODE"
        }
        Remove-Item -LiteralPath $restoreReg -Force -ErrorAction SilentlyContinue
        Write-Host 'Restored WSA LocalState.'
    }
    finally {
        & cmd.exe /c "reg unload $mountName >nul 2>nul & exit /b 0" | Out-Null
    }
}

Write-Host 'Restore finished.'
