# Open With Toolkit

**Inspect Windows file-association registrations, review Open With entries, and export reports — from a small PowerShell toolkit.**

Open With Toolkit is a set of Windows batch and PowerShell scripts for inspecting file-association registry data. It includes a read-only scan of `UserChoice`, extension-level inspection, application-registration search, and a guarded workflow for removing selected per-user Open With values.

> **Safety note:** Registry changes can affect how Windows opens files. Review every target carefully. The toolkit does not edit `UserChoice` or its `Hash` value. Its manager is limited to selected per-user (`HKCU`) values and attempts to export a registry backup before deleting a value.

**Languages:** [English](README.md) · [Bahasa Indonesia](README.id.md)

## Features

- **Scan UserChoice** — list extensions with a `UserChoice` key and export the results to CSV and TXT.
- **Inspect an extension** — review discovered `UserChoice`, ProgID, Open With, SupportedTypes, and related registration hints.
- **Search for an app** — search selected registry locations for application registrations, App Paths, uninstall entries, and available current-user Appx packages.
- **Manage selected Open With values** — remove supported per-user values after confirmation, with a registry export attempt and post-delete verification.

The results depend on what is registered on the current Windows installation. A missing result does not prove that an app is not installed or cannot open a file.

## Included scripts

| File | Purpose |
| --- | --- |
| `Manage-OpenWithChoices.bat` | Launches the interactive toolkit |
| `Manage-OpenWithChoices.ps1` | Main menu: scan, inspect, manage, and search |
| `Read-OpenWithRegistry.bat` / `.ps1` | Separate registry reader |
| `Add-OpenWithApp.bat` / `.ps1` | Separate helper for adding an app to Open With registration |

## Requirements

- Windows
- Windows PowerShell (the inbox Windows PowerShell is the intended runtime)
- A user account with access to the registry locations being inspected

No administrator elevation is normally needed for the read-only features. Avoid running the toolkit as Administrator unless you understand why it is necessary.

## Quick start

1. Download or clone this repository.
2. Extract it if you downloaded a ZIP.
3. Open the project folder in File Explorer.
4. Double-click `Manage-OpenWithChoices.bat`.

Or launch it from PowerShell:

```powershell
.\Manage-OpenWithChoices.bat
```

The main menu provides:

1. **Scan UserChoice** — read-only scan and CSV/TXT export.
2. **Inspect Extension** — enter an extension such as `.php` or `.json`.
3. **Manage Open With** — inspect candidate entries and, where allowed, remove a selected per-user value.
4. **Search App** — search supported registry sources for an app name or executable.
5. **Exit**

Reports and registry backups are written under `OpenWith-Backups` next to the toolkit when the corresponding operation creates them.

## Safety and limitations

- The toolkit is intended for inspection and careful, targeted maintenance—not bulk cleanup.
- `UserChoice` and its `Hash` value are treated as read-only. Use **Windows Settings → Apps → Default apps** to change a default app.
- Deletion is restricted to supported per-user (`HKCU`) values. Machine-wide (`HKLM`) registrations, application commands, and `UserChoice` are not deleted by the manager.
- Before a supported deletion, the manager attempts to export the target registry key. If the export fails, deletion is cancelled.
- A successful registry export and a post-delete check are useful safeguards, but they are not a substitute for understanding the selected entry.
- Registry registrations vary between Windows versions and applications. The toolkit may not discover every possible registration path.
- The scripts have been tested manually on one Windows environment for the workflows documented in the project; that does not guarantee compatibility with every Windows setup.

**Before changing anything:** run the read-only scan and inspection first. For a first-time test of deletion, use a disposable test entry—not an extension you rely on.

## Output and privacy

Scan and search reports can reveal installed applications, file extensions, registry paths, and local installation locations. Review generated CSV, TXT, and `.reg` files before sharing them.

Do not commit personal reports, registry exports, or machine-specific output to a public repository.

## Contributing

Bug reports and focused improvements are welcome. Include your Windows version, the menu used, the exact error message, and a redacted example of the relevant output. Do not attach registry exports that contain personal or machine-specific information without reviewing them first.

## License

No license has been included yet. Until a license is added, you should not assume that the code is available for reuse, redistribution, or modification under an open-source license.
