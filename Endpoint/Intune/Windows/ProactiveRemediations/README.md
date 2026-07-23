# Intune - Windows - Proactive Remediations

Endpoint Analytics proactive remediations: paired detection and remediation scripts.

Proactive remediations are Intune's take on Configuration Manager's Configuration
Item/Baseline. Each consists of a detection script that evaluates current state, and a
remediation script that runs only when the device does not match the desired state.

Find them in the [Microsoft Intune admin center](https://intune.microsoft.com/) under
**Reports > Endpoint analytics > Proactive remediations**.

---

## Project artifacts

Each remediation folder contains:

| Artifact | Description |
| --- | --- |
| `README.md` | Description, Intune configuration, and desired state |
| `Detect-*.ps1` | Detection script. Exit 0 when compliant, exit 1 to trigger remediation |
| `Remediate-*.ps1` | Remediation script. Runs only when detection exits 1 |

`Detect-` and `Remediate-` are deliberate exceptions to the approved-verb rule; they mirror
Intune's own vocabulary. See [naming conventions](../../../../docs/NAMING-CONVENTIONS.md).

---

## Projects

| Project | Description |
| --- | --- |
| [Change-WinVerOEMInfo](./Change-WinVerOEMInfo/README.md) | Sets OEM support information and registered owner/organisation branding in the registry |
| [Clear-MicrosoftAppsCache](./Clear-MicrosoftAppsCache/README.md) | Checks the ClickToRunSvc service and starts it when stopped |
| [Create-LocalAdminAccount](./Create-LocalAdminAccount/README.md) | Detects and creates a local administrator account |
| [Disable-RunCommand](./Disable-RunCommand/README.md) | Disables the Run command via registry policy |
| [Disable-WindowsFastBoot](./Disable-WindowsFastBoot/README.md) | Detects and disables Windows Fast Boot (fast startup) |
| [MicrosoftStore-ForcedAutoUpdate](./MicrosoftStore-ForcedAutoUpdate/README.md) | Forces application updates in the Microsoft Store |
| [UninstallApp/Zscaler](./UninstallApp/Zscaler/README.md) | Detects and uninstalls the Zscaler application |
| [WindowsUpdate/RemoveWUEntries](./WindowsUpdate/RemoveWUEntries/README.md) | Removes leftover Windows Update policy values from the policy key and both cache sets |

---

## Structure

```
ProactiveRemediations/
├── Change-WinVerOEMInfo/
├── Clear-MicrosoftAppsCache/
├── Create-LocalAdminAccount/
├── Disable-RunCommand/
├── Disable-WindowsFastBoot/
├── MicrosoftStore-ForcedAutoUpdate/
├── UninstallApp/
│   └── Zscaler/
├── WindowsUpdate/
│   └── RemoveWUEntries/
└── media/
```

---

## A note on the built-in ClickToRun remediation

`Clear-MicrosoftAppsCache` is based on Microsoft's built-in proactive remediation, with a
correction. The original contains a bug:

```powershell
$ctr = 0
while ($curSvcStat -eq "Stopped") {
    Start-Sleep -Seconds 5
    ctr++              # <-- should be $ctr++
    if (ctr -eq 12) {  # <-- should be $ctr
        Write-Output "Office C2R service could not be started after 60 seconds"
        exit 1
    }
}
```

`ctr` without the `$` is parsed as a command, not a variable. `$ctr` never increments, the
exit condition never fires, and the loop runs forever. The corrected version uses `$ctr`
in both places.

---

## Shared prerequisites

| Requirement | Detail |
| --- | --- |
| PowerShell | 5.1 or later |
| Context | SYSTEM by default; scripts requiring user context say so in their README |
| Permissions | Intune Administrator to upload and assign |

Run detection scripts in the 64-bit PowerShell host unless a project README says otherwise.

---

## Related

- [Compliance](../Compliance/README.md) - custom compliance policies
- [DeviceScripts](../DeviceScripts/README.md) - platform scripts that run once
- [Win32Apps](../Win32Apps/README.md) - application packaging

---

[Back to repository root](../../../../README.md)
