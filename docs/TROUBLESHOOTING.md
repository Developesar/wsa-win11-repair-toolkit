# Troubleshooting

## PowerShell says the script must run as Administrator

The repair script needs Administrator access to:

- Register the WSA AppX manifest.
- Patch files under the WSA install directory.
- Load and edit the WSA settings hive.
- Restart HNS, VM Compute, and IP Helper.

Open PowerShell with **Run as Administrator** and run the command again.

## `Patch anchor not found`

The local `WsaClient.exe` does not match the known byte layout used by this repair.

In this case, the script intentionally refuses to patch the file. Do not force the binary patch on an unknown WSA version.

Recommended next steps:

1. Run:

   ```powershell
   .\scripts\Show-WSAStatus.ps1
   ```

2. Record the WSA version and the relevant Event Viewer crash details.
3. Open an issue or update the repair logic for that specific version.

## Internet still does not work after disabling Local Network Access

HNS may not have rebuilt the WSA NAT network yet.

Run:

```powershell
.\scripts\Repair-WSAWin11.ps1 -RefreshHns -LaunchPlayStore -Verify
```

This restarts:

- `hns`
- `vmcompute`
- `iphlpsvc`

This may briefly interrupt WSL, Docker, or Hyper-V virtual machines.

## `adb devices` shows `unauthorized`

WSA Developer Mode is enabled, but Android has not accepted the ADB key yet.

Open WSA, approve the ADB authorization prompt, and run:

```powershell
adb connect 127.0.0.1:58526
adb devices
```

Expected output:

```text
127.0.0.1:58526    device
```

## Google Play opens but sign-in is stuck

First test WSA networking:

```powershell
.\scripts\Show-WSAStatus.ps1
```

If `google.com` works but sign-in is still stuck, the issue may be related to Google Play Services, Play Integrity, system time, account restrictions, or a VPN/proxy configuration.

If the Windows machine uses a VPN or proxy, a system-level VPN or TUN mode is usually more reliable than a loopback proxy such as `127.0.0.1:10809`, because WSA cannot always use Windows loopback proxies directly.

## Restore from Backup

Every repair run creates a backup folder:

```text
backups/<timestamp>/
```

To restore:

```powershell
.\scripts\Restore-WSABackup.ps1 -BackupDirectory .\backups\<timestamp>
```

The restore script can restore:

- The WSA manifest backup, if one was created.
- The `WsaClient.exe` backup, if one was created.
- The WSA `LocalState` registry export, if one was created.
