# Configuration Reference

The tracked example is Config/config.example.json.

## Top-level settings

| Property | Type | Description |
| --- | --- | --- |
| CheckIntervalSeconds | integer | Delay between enforcement passes. Minimum 5 seconds. |
| LogMaxSizeMB | integer | Maximum enforcement log size before rotation. |
| LogRetentionCount | integer | Number of archived enforcement logs to retain. |
| RemoveShortcuts | boolean | Enables or disables configured shortcut removal. |
| ShortcutNames | array | Exact shortcut filenames to remove. |
| MachineRegistry | array | Machine-level registry values to enforce. |
| UserRegistry | array | Loaded-user registry values to enforce. |

## MachineRegistry

Each entry contains Path, Name, Type, and Value. Type currently supports DWord.

Example:

    Path  = HKLM:\SOFTWARE\Policies\Microsoft\Edge
    Name  = SyncDisabled
    Type  = DWord
    Value = 0

## UserRegistry

User settings use a path relative to each loaded user hive.

Example:

    RelativePath = Software\Microsoft\Clipboard
    Name         = EnableCloudClipboard
    Type         = DWord
    Value        = 1

At runtime the engine writes to:

    Registry::HKEY_USERS\SID\Software\Microsoft\Clipboard

## Shortcut cleanup

The tracked example ships with shortcut removal disabled and an empty ShortcutNames array. Enable it only after adding exact shortcut filenames and testing in audit-only mode.

## Installed configuration

The installer creates:

    C:\ProgramData\DesktopPolicy-Guard\config.json

An existing installed configuration is preserved on reinstall.

## Process behavior

Per-setting failures are logged and the enforcement loop continues. Fatal startup failures such as a missing or invalid configuration cause the PowerShell process to exit so WinSW can apply service recovery behavior.
## AppUpdates

| Property | Type | Description |
| --- | --- | --- |
| Enabled | boolean | Enables scheduled application maintenance. |
| Mode | string | All or AllowList. |
| IncludeUnknown | boolean | Includes packages whose installed version cannot be determined. |
| ExcludedPackages | array | Package IDs to skip. In All mode these are maintained as WinGet pins. |
| Packages | array | Package IDs targeted when Mode is AllowList. |

Tracked defaults:

    Enabled          = false
    Mode             = All
    IncludeUnknown   = false
    ExcludedPackages = Microsoft.PowerShell
    Packages         = empty

The App Update Maintenance installer adds this section automatically when an existing installed configuration predates the feature.

## App Update Maintenance task

The updater runs in the installing administrator's user context rather than LocalSystem.

Default task location:

    \DesktopPolicy-Guard\App Update Maintenance

The task folder, name, schedule, and install directory are parameters of Install-AppUpdateMaintenance.ps1.

