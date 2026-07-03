# What Was Fixed

This document describes the real repair case that produced this repository.

## Test Environment

- Windows 11 24H2
- WSA `2407.40000.4.0`
- Sideloaded/development WSA installation
- Laptop with NVIDIA discrete GPU and Intel integrated GPU

## Issue 1: WSA Client Crash

Symptoms:

- Starting `wsa://com.android.settings` or Google Play caused `WsaClient.exe` to crash.
- Windows Event Viewer showed failures involving:
  - `MoAppCrash`
  - `combase.dll`
  - Access-denied style failures related to `80070005`

Repair:

1. The WSA AppX manifest was inspected.
2. The restricted app URI handler capability was added and the package was re-registered.
3. Because the manifest-only fix did not resolve the crash on this build, a guarded two-byte-pattern patch was applied to `WsaClient.exe`.
4. After the binary patch, WSA Settings and Google Play launched without new crash events.

Relevant script:

```powershell
.\scripts\Repair-WSAWin11.ps1 -AddManifestCapability -ApplyCrashPatch
```

## Issue 2: WSA Internet Access

Symptoms inside Android logcat:

- `Network is unreachable`
- `No route to host`
- `Unknown host: time.android.com`
- DNS timeouts

Important observation:

- With WSA Local/Advanced networking enabled, Android received a LAN-style `192.168.x.x/24` address and could not reach the expected gateway or DNS.
- Google Play and Google account sign-in could not use the network reliably.

Repair:

1. `LocalNetworkAccessEnabled` was disabled in the WSA settings hive.
2. The setting was written while preserving the original UWP registry value type, such as `hex(5f5e10b)`. Writing it as a plain `REG_NONE` value can break WSA settings.
3. The Windows host networking services were refreshed:
   - `hns`
   - `vmcompute`
   - `iphlpsvc`

After repair:

- Android received a Windows NAT address such as `172.30.x.x/20`.
- Android had a default route such as `172.30.x.1`.
- DNS also pointed to the Windows NAT gateway.
- Android connectivity state became `IS_VALIDATED`.
- `google.com`, `accounts.google.com`, and `play.googleapis.com` responded.

Relevant script:

```powershell
.\scripts\Repair-WSAWin11.ps1 -DisableLocalNetworkAccess -RefreshHns -Verify
```

## GPU Preference

The Windows graphics preference for `WsaClient.exe` was set to:

```text
GpuPreference=2;
```

That is the Windows `High performance` preference and usually selects the stronger GPU on dual-GPU laptops.
