# Contributing

Thanks for considering a contribution.

This project deals with Windows AppX packages, WSA binaries, and host networking services. Please keep changes conservative, reversible, and well documented.

## Good Bug Reports

Please include:

- Windows edition, version, and build.
- WSA package version.
- WSA source or build type, such as Store, sideloaded, WSABuilds, or MagiskOnWSA-style.
- Whether the package is installed in development mode.
- Event Viewer crash details, including faulting module and exception code.
- ADB network output, when available:

  ```powershell
  adb connect 127.0.0.1:58526
  adb shell ip addr show eth0
  adb shell ip route show table 1002
  adb shell ping -c 1 -W 3 google.com
  ```

Do not attach personal logs unless you have reviewed and sanitized them.

## Development Guidelines

- Keep scripts compatible with Windows PowerShell 5.1 where possible.
- Prefer explicit backups before modifying files or registry hives.
- Do not patch unknown binaries. If a byte anchor is not found, stop with a clear error.
- Keep repository files in English.
- Keep tracked files ASCII-only unless there is a clear reason not to.
- Do not commit local logs, registry exports, dumps, or machine-specific artifacts.

## Pull Request Checklist

- [ ] The change is documented in `README.md` or `docs/`.
- [ ] Scripts parse successfully with PowerShell.
- [ ] The change does not add local machine paths, usernames, tokens, or private logs.
- [ ] Rollback or backup behavior is preserved.
