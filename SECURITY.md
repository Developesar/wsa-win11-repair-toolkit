# Security Policy

## Scope

This repository contains repair scripts for local Windows machines. The scripts may:

- Register a WSA AppX manifest.
- Patch `WsaClient.exe` only when known byte patterns are found.
- Load and edit the WSA settings hive.
- Restart Windows networking services.

Review the scripts before running them on a machine you care about.

## Reporting Security Issues

If you find a security issue, please do not include private tokens, full crash dumps, or unsanitized registry exports in a public issue.

Open a minimal report with:

- Affected script.
- Expected behavior.
- Actual behavior.
- Safe reproduction steps.
- Sanitized logs or snippets.

## Data Handling

The scripts write backups and logs locally under:

- `backups/`
- `logs/`

These folders are ignored by git. Review them before sharing.
