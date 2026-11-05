# DesktopPolicy-Guard

Windows workstation service for continuously enforcing selected machine and loaded-user registry settings without leaving an interactive PowerShell window open.

The project is intended for cases where an approved local exception must remain in place even when centrally managed policy periodically changes the same setting.

> The preferred long-term fix is to correct the authoritative GPO, Intune, or application-management policy. Use this tool only where a local exception is authorized.

---

## Capabilities

- Runs continuously as a Windows service under LocalSystem.
- Uses WinSW as the service wrapper without committing a binary to the repository.
- Enforces configured HKLM registry values.
- Enumerates loaded user hives under HKEY_USERS and enforces configured per-user values.
- Resolves loaded-user Desktop paths before optional shortcut cleanup.
- Supports audit-only testing before installation.
- Writes rotating logs and a JSON status heartbeat.
- Keeps configuration separate from code.
- Adds optional WinGet application maintenance as a separate short-lived scheduled task.
- Supports WinGet upgrade-all and allow-list modes with exclusions.
- Excludes Microsoft.PowerShell from automated WinGet updates by default.

---

## Project structure

~~~text
Windows/
|-- Client/
    |-- DesktopPolicy-Guard/
        |-- Config/
        |   |-- config.example.json
        |-- Docs/
        |   |-- AppUpdate-Maintenance.md
        |   |-- Operational-Notes.md
        |   |-- Reference.md
        |-- Tests/
        |   |-- DesktopPolicy-Guard.Tests.ps1
        |-- Logs/
        |   |-- .gitkeep
        |-- Install-DesktopPolicyGuardService.ps1
        |-- Start-DesktopPolicyGuard.ps1
        |-- Remove-DesktopPolicyGuardService.ps1
        |-- Test-DesktopPolicyGuard.ps1
        |-- Install-AppUpdateMaintenance.ps1
        |-- Start-AppUpdateMaintenance.ps1
        |-- Remove-AppUpdateMaintenance.ps1
        |-- Test-AppUpdateMaintenance.ps1
        |-- README.md
        |-- CHANGELOG.md
        |-- .gitignore
~~~

---

## Install

Open Windows PowerShell as Administrator:

~~~powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\Install-DesktopPolicyGuardService.ps1
~~~

For restricted networks:

~~~powershell
.\Install-DesktopPolicyGuardService.ps1 -WinSWSourcePath C:\Tools\WinSW-x64.exe
~~~

Preview installation:

~~~powershell
.\Install-DesktopPolicyGuardService.ps1 -WhatIf
~~~

## Audit before installation

~~~powershell
.\Test-DesktopPolicyGuard.ps1
~~~

The audit helper runs one pass with RunOnce and AuditOnly, so it does not change registry values or remove shortcuts.

## App Update Maintenance

The application updater is intentionally separate from the LocalSystem policy service. The WinGet CLI is not supported in LocalSystem context, so the updater runs as a short-lived scheduled task under the administrator account that installs it.

Test WinGet first:

~~~powershell
winget --version
winget source update
winget upgrade
~~~

Then run the project audit:

~~~powershell
.\Test-AppUpdateMaintenance.ps1
~~~

Install daily maintenance from an elevated PowerShell 7 session:

~~~powershell
.\Install-AppUpdateMaintenance.ps1 -Enable -Mode All -StartNow
~~~

Use an existing Task Scheduler folder when desired:

~~~powershell
.\Install-AppUpdateMaintenance.ps1 `
    -TaskPath '\IT-Automation\' `
    -Enable `
    -Mode All `
    -StartNow
~~~

The task launches hidden, performs maintenance, writes a report, and exits. It does not leave a persistent PowerShell or Windows Terminal window running.

All mode uses winget upgrade --all. Package IDs in ExcludedPackages are pinned first so WinGet skips them. AllowList mode updates only IDs listed in Packages.

Microsoft.PowerShell is excluded in the tracked example because WinGet can report a newer release while refusing an in-place upgrade when installer technologies differ.

---
## Configuration

The tracked example is Config/config.example.json. Copy it to Config/config.json for a working repository-local configuration. Config/config.json is ignored by git.

Shortcut deletion and App Update Maintenance are disabled by default. The App Update Maintenance installer adds the AppUpdates section automatically when upgrading an older installed configuration.

## Installed layout

~~~text
C:\ProgramData\DesktopPolicy-Guard\
|-- DesktopPolicyGuard.exe
|-- DesktopPolicyGuard.xml
|-- Start-DesktopPolicyGuard.ps1
|-- Start-AppUpdateMaintenance.ps1
|-- config.json
|-- Logs\
|   |-- AppUpdateMaintenance\
|-- Status\
    |-- status.json
~~~

The WinSW executable is downloaded at install time and is not stored in this repository.

## Verify

~~~powershell
Get-Service DesktopPolicyGuard
Get-Content 'C:\ProgramData\DesktopPolicy-Guard\Status\status.json' -Raw
Get-Content 'C:\ProgramData\DesktopPolicy-Guard\Logs\DesktopPolicyGuard.log' -Tail 50
~~~

## Remove

~~~powershell
.\Remove-DesktopPolicyGuardService.ps1
~~~

To also delete installed files and runtime data:

~~~powershell
.\Remove-DesktopPolicyGuardService.ps1 -RemoveInstalledFiles
~~~

## Safety features

- AuditOnly reports drift without modifying state.
- RunOnce supports controlled one-pass validation.
- The installer supports WhatIf.
- Existing installed config.json is preserved on reinstall.
- Shortcut deletion is disabled in the tracked example configuration.
- No WinSW executable is committed to the repository.
- Registry writes are verified after enforcement.
- App Update Maintenance has a separate audit-only mode.
- App updates are disabled in the tracked example configuration.
- Microsoft.PowerShell is excluded from automated app updates by default.
- The app maintenance task uses StartWhenAvailable and a four-hour execution limit.

## Scope notes

This project deliberately does not change GPO, Intune, or Edge-management configuration; determine which central policy is responsible for drift; load offline user hives; guarantee access to network-redirected Desktop folders; store credentials or tenant-specific identifiers; or bundle executable binaries.

Only currently loaded user hives are processed.

WinGet package behavior is controlled by each package manifest and installer. Test important applications individually before enabling broad unattended updates.

## Testing

~~~powershell
Invoke-Pester .\Tests\DesktopPolicy-Guard.Tests.ps1
~~~

## Documentation

- [App Update Maintenance](./Docs/AppUpdate-Maintenance.md)
- [Operational Notes](./Docs/Operational-Notes.md)
- [Configuration Reference](./Docs/Reference.md)
- [Changelog](./CHANGELOG.md)

## Author

**Joel Cottrell** - [github.com/joelcottrell](https://github.com/joelcottrell)

## License

See [LICENSE](../../../LICENSE).

---

> Always test in a non-production environment first.
