# WSA Windows 11 Crash and Network Fix

PowerShell tools and notes for repairing common Windows Subsystem for Android issues on Windows 11:

- `WsaClient.exe` crashes or WSA does not open.
- Android apps inside WSA have no internet access.
- Google Play or Google account sign-in gets stuck because Android reports `Network is unreachable`, `No route to host`, or DNS timeouts.

This repository was created from a real repair session on Windows 11 24H2 with a sideloaded WSA `2407.40000.4.0` build.

## Important Warning

Microsoft ended official WSA support. These scripts are intended for sideloaded or development WSA builds such as WSABuilds or MagiskOnWSA-style packages.

Use at your own risk. The scripts create backups before changing WSA files or settings, but they still modify a Windows AppX package, WSA settings, and Hyper-V/HNS networking services.

Run PowerShell as **Administrator** before using the repair script.

## Quick Start

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\scripts\Repair-WSAWin11.ps1 -All
```

`-All` runs the full repair flow:

- Adds the missing app URI capability when needed.
- Applies the guarded `WsaClient.exe` crash patch when the known byte pattern is found.
- Sets WSA to use the Windows `High performance` GPU preference.
- Disables WSA Local/Advanced networking so WSA uses stable Windows NAT networking.
- Refreshes HNS, VM Compute, and IP Helper.
- Launches Google Play.
- Verifies WSA networking with ADB when `adb.exe` is available.

## Safer Staged Usage

If WSA opens but Android has no internet:

```powershell
.\scripts\Repair-WSAWin11.ps1 -SetHighPerformanceGpu -DisableLocalNetworkAccess -RefreshHns -LaunchPlayStore -Verify
```

If WSA crashes or does not open:

```powershell
.\scripts\Repair-WSAWin11.ps1 -AddManifestCapability -ApplyCrashPatch -LaunchPlayStore -Verify
```

To inspect the current status:

```powershell
.\scripts\Show-WSAStatus.ps1
```

## Repository Contents

- `scripts/Repair-WSAWin11.ps1`: Main repair script.
- `scripts/Show-WSAStatus.ps1`: Status and network diagnostic script.
- `scripts/Restore-WSABackup.ps1`: Restore files and settings from a backup created by the repair script.
- `docs/WHAT_WE_FIXED.md`: Technical explanation of the repair case this repository came from.
- `docs/TROUBLESHOOTING.md`: Common errors and recovery steps.

## Backups and Logs

Every repair run writes local output to:

- `backups/<timestamp>/`
- `logs/repair-<timestamp>.log`

Those folders are ignored by git and should not be committed.

To restore a previous run:

```powershell
.\scripts\Restore-WSABackup.ps1 -BackupDirectory .\backups\<timestamp>
```

## Expected Result

After a successful repair:

- `WsaClient.exe`, `WsaService.exe`, and `vmmemWSA` keep running without new crash events.
- `adb devices` shows `127.0.0.1:58526 device` when Developer Mode and ADB authorization are available.
- Android inside WSA has a NAT route such as `default via 172.x.x.1`.
- `ping google.com` and `ping accounts.google.com` work from inside WSA.
- Google Play and the Google account sign-in flow can open.

## Privacy

The repository is designed not to include local logs, machine-specific backups, tokens, account data, or user profile paths.

Before publishing your own fork, you can check tracked files with:

```powershell
git ls-files
```

Only source scripts and documentation should be tracked.

## Future Translations

All current repository content is intentionally English. A Persian translation can be added later under a separate path such as `docs/fa/`.
