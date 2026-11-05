# Operational Notes

## Service model

DesktopPolicy-Guard runs as a Windows service under LocalSystem. WinSW owns the service lifecycle and launches Windows PowerShell in Session 0, so the enforcement loop does not create a visible PowerShell or Windows Terminal window in the signed-in user's desktop session.

Default service name: **Desktop Policy Guard**

Default service ID: **DesktopPolicyGuard**

## User registry handling

A service running as LocalSystem cannot use normal HKCU to target the signed-in user. The engine therefore:

1. Reads profile registrations from HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList.
2. Checks which matching hives are currently loaded under HKEY_USERS.
3. Applies configured user settings directly to HKEY_USERS\SID\RelativePath.

Offline profiles are not loaded or modified.

## Desktop path handling

For each loaded user, the engine reads Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders and resolves the Desktop known-folder value. If that cannot be resolved, it falls back to ProfilePath\Desktop.

A Desktop redirected to a network location may not be accessible to LocalSystem.

## Logging

Enforcement log:

    C:\ProgramData\DesktopPolicy-Guard\Logs\DesktopPolicyGuard.log

Status heartbeat:

    C:\ProgramData\DesktopPolicy-Guard\Status\status.json

The log rotates at the configured maximum size and retains the configured number of archives.

## WinSW

The installer is pinned to WinSW 2.12.0 x64. The executable is downloaded from the official WinSW GitHub release at installation time unless -WinSWSourcePath is supplied.

The repository intentionally does not commit executable binaries.

## Upgrade behavior

Re-running the installer replaces the service script and wrapper configuration but preserves an existing installed config.json.

## Failure modes

| Symptom | Likely cause | Resolution |
| --- | --- | --- |
| Service fails to install | PowerShell is not elevated | Run installer as Administrator |
| WinSW download fails | GitHub access blocked | Supply -WinSWSourcePath |
| User values remain unchanged | User hive is not loaded | Sign in and allow the next enforcement pass |
| Shortcut remains | Cleanup disabled or path inaccessible | Review config.json and service log |
| Network redirected Desktop is skipped | LocalSystem lacks network access | Use another deployment method for that path |
| Policy changes back repeatedly | Central policy remains authoritative | Correct or exempt the central policy when possible |

## Rollback

Run Remove-DesktopPolicyGuardService.ps1. Add -RemoveInstalledFiles to remove the installed files as well.

Removing the service does not restore prior registry values or deleted shortcuts.
## App Update Maintenance model

WinGet maintenance is deliberately not hosted inside the LocalSystem Windows service.

winget.exe is delivered through App Installer and is not supported in LocalSystem context. The maintenance task therefore runs in the user context of the administrator who installs it, with highest privileges, and exits after each run.

This avoids a persistent interactive PowerShell process while preserving access to the same WinGet package inventory that was validated manually.

Default task path:

    \DesktopPolicy-Guard\App Update Maintenance

The task path is configurable. Existing Task Scheduler folders such as \BCH-IT\ can be selected during installation.

### Scheduling

The task runs daily, uses StartWhenAvailable, ignores duplicate starts, and has a four-hour execution limit.

### Exclusions and pins

In All mode, ExcludedPackages are ensured as WinGet pins before winget upgrade --all. A normal WinGet pin prevents the package from participating in upgrade-all while still allowing a deliberate targeted upgrade outside this automation.

The uninstaller does not remove pins automatically.

### PowerShell

Microsoft.PowerShell is excluded by default because WinGet can identify a newer release while refusing an in-place upgrade when the installed and available package use different installer technologies. Remove the exclusion only after a direct upgrade path is tested successfully.

### App update logs

Each run writes:

    C:\ProgramData\DesktopPolicy-Guard\Logs\AppUpdateMaintenance\AppUpdateMaintenance-<timestamp>.log
    C:\ProgramData\DesktopPolicy-Guard\Logs\AppUpdateMaintenance\AppUpdateMaintenance-<timestamp>.json

