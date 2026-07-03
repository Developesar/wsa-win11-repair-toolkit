# WSA Windows 11 Repair Toolkit

[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-2f6db5?logo=powershell)](https://learn.microsoft.com/powershell/)
[![Windows](https://img.shields.io/badge/Windows-11-0078d4?logo=windows)](https://www.microsoft.com/windows/)
[![WSA](https://img.shields.io/badge/WSA-sideloaded%20builds-orange)](#supported-scenarios)
[![License](https://img.shields.io/badge/license-MIT-green)](LICENSE)

PowerShell repair tools for Windows Subsystem for Android on Windows 11.

This project focuses on two failure modes often seen with sideloaded WSA builds:

- `WsaClient.exe` crashes or WSA does not open.
- Android apps inside WSA have no internet access, causing Google Play or Google account sign-in to fail with errors such as `Network is unreachable`, `No route to host`, or DNS timeouts.

The toolkit was created from a real Windows 11 24H2 repair session with a sideloaded WSA `2407.40000.4.0` build.

## Table of Contents

- [Problems This Toolkit Targets](#problems-this-toolkit-targets)
- [Important Warning](#important-warning)
- [Supported Scenarios](#supported-scenarios)
- [Quick Start](#quick-start)
- [Safer Staged Usage](#safer-staged-usage)
- [What the Repair Does](#what-the-repair-does)
- [Backups and Restore](#backups-and-restore)
- [Expected Result](#expected-result)
- [Repository Layout](#repository-layout)
- [Privacy](#privacy)
- [GitHub Repository Metadata](#github-repository-metadata)
- [Contributing](#contributing)

## Problems This Toolkit Targets

This project is meant to be discoverable by users searching for real WSA failure symptoms, including:

- Windows Subsystem for Android crash fix on Windows 11.
- WSA not opening after Windows 11 24H2 update.
- `WsaClient.exe` crash, `MoAppCrash`, `MoBEX`, `combase.dll`, or `ucrtbase.dll`.
- WSA sideloaded build crash on app launch.
- WSABuilds or MagiskOnWSA `WsaClient.exe` repair.
- WSA Google Play not working.
- WSA Google account sign-in stuck.
- WSA no internet, DNS timeout, `Network is unreachable`, or `No route to host`.
- WSA Advanced Networking or Local Network Access breaks Android internet.
- WSA NAT networking repair using HNS, VM Compute, and IP Helper.

If your Android apps inside WSA open but cannot reach Google Play, `accounts.google.com`, or `play.googleapis.com`, start with the network repair flow. If WSA crashes before Android apps open, start with the crash repair flow.

## Important Warning

Microsoft ended official WSA support. This repository is intended for sideloaded or development WSA packages such as WSABuilds or MagiskOnWSA-style builds.

Use at your own risk. The repair script can modify a Windows AppX package, patch `WsaClient.exe` when a known byte pattern is found, edit the WSA settings hive, and restart Windows host networking services.

Run PowerShell as **Administrator** before using the repair script.

## Supported Scenarios

| Scenario | Script action |
| --- | --- |
| WSA opens but Android has no internet | Disable WSA Local/Advanced networking and refresh HNS NAT |
| WSA crashes on app launch | Add app URI capability and apply a guarded WSA client crash patch |
| Dual-GPU laptop performance issues | Set Windows graphics preference for `WsaClient.exe` to `High performance` |
| Need status before or after repair | Run the status script and ADB network checks |
| Need rollback | Restore from the backup folder created by the repair run |

## Quick Start

Open PowerShell as Administrator:

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

## What the Repair Does

### Crash repair

Some sideloaded WSA builds can crash in the app URI handler path on newer Windows 11 builds. The repair script first tries the manifest capability fix, then applies a guarded binary patch only if the expected byte patterns are present.

If the expected byte patterns are not found, the script stops instead of patching an unknown binary.

### Network repair

When WSA Local/Advanced networking is enabled, Android may receive a LAN-style address but fail to reach the gateway or DNS. The repair script disables that mode while preserving the original UWP registry value type, then refreshes Windows host networking so WSA can use a clean NAT network.

### GPU preference

The script sets this Windows graphics preference for `WsaClient.exe`:

```text
GpuPreference=2;
```

That is the Windows `High performance` setting and usually selects the stronger GPU on dual-GPU laptops.

## Backups and Restore

Every repair run writes local output to:

- `backups/<timestamp>/`
- `logs/repair-<timestamp>.log`

These folders are ignored by git and should not be committed.

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

## Repository Layout

```text
.
|-- docs/
|   |-- TROUBLESHOOTING.md
|   `-- WHAT_WE_FIXED.md
|-- scripts/
|   |-- Repair-WSAWin11.ps1
|   |-- Restore-WSABackup.ps1
|   `-- Show-WSAStatus.ps1
|-- .github/
|   |-- ISSUE_TEMPLATE/
|   `-- workflows/
|-- LICENSE
|-- CONTRIBUTING.md
|-- SECURITY.md
|-- CHANGELOG.md
`-- README.md
```

## Privacy

The repository is designed not to include local logs, machine-specific backups, tokens, account data, or user profile paths.

Before publishing your own fork, verify tracked files with:

```powershell
git ls-files
```

Only source scripts and documentation should be tracked.

## GitHub Repository Metadata

Recommended GitHub repository name:

```text
wsa-win11-repair-toolkit
```

Recommended short description:

```text
PowerShell toolkit to repair Windows Subsystem for Android crashes and NAT networking on Windows 11.
```

Recommended GitHub topics:

```text
wsa
windows-subsystem-for-android
windows-11
powershell
wsa-repair
wsabuilds
magiskonwsa
google-play
android
hyper-v
hns
networking
```

## Contributing

Bug reports and version-specific findings are welcome. Please include:

- Windows version and build.
- WSA package version.
- Whether WSA is Store, sideloaded, WSABuilds, or MagiskOnWSA-style.
- Relevant Event Viewer crash module and exception code.
- Network symptoms from ADB or logcat.

See [CONTRIBUTING.md](CONTRIBUTING.md) for details.

## Future Translations

All current repository content is intentionally English. A Persian translation can be added later under a separate path such as `docs/fa/`.
