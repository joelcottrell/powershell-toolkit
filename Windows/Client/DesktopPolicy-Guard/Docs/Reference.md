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
