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

---

## Project structure

~~~text
Windows/
|-- Client/
    |-- DesktopPolicy-Guard/
        |-- Config/
        |   |-- config.example.json
        |-- Docs/
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

## Configuration

The tracked example is Config/config.example.json. Copy it to Config/config.json for a working repository-local configuration. Config/config.json is ignored by git.

Shortcut deletion is disabled by default.

## Installed layout

~~~text
C:\ProgramData\DesktopPolicy-Guard\
|-- DesktopPolicyGuard.exe
|-- DesktopPolicyGuard.xml
|-- Start-DesktopPolicyGuard.ps1
|-- config.json
|-- Logs\
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

## Scope notes

This project deliberately does not change GPO, Intune, or Edge-management configuration; determine which central policy is responsible for drift; load offline user hives; guarantee access to network-redirected Desktop folders; store credentials or tenant-specific identifiers; or bundle executable binaries.

Only currently loaded user hives are processed.

## Testing

~~~powershell
Invoke-Pester .\Tests\DesktopPolicy-Guard.Tests.ps1
~~~

## Documentation

- [Operational Notes](./Docs/Operational-Notes.md)
- [Configuration Reference](./Docs/Reference.md)
- [Changelog](./CHANGELOG.md)

## Author

**Joel Cottrell** - [github.com/joelcottrell](https://github.com/joelcottrell)

## License

See [LICENSE](../../../LICENSE).

---

> Always test in a non-production environment first.
