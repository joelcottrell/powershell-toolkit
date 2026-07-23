# Intune - Windows - Device Scripts

Intune platform scripts: PowerShell that runs once on a Windows device, outside the
detect-and-remediate model.

**Belongs here:** one-shot configuration applied at enrolment or on assignment - branding,
personalization, debloat, and similar.

**Does not belong here:** paired detection/remediation logic, which is
[ProactiveRemediations](../ProactiveRemediations/README.md), or application packaging, which
is [Win32Apps](../Win32Apps/README.md).

---

## Projects

| Project | Description |
| --- | --- |
| [Set-Lockscreen](./Set-Lockscreen/README.md) | Set, revert, and detect the lock screen and desktop background |
| [Debloat-Windows](./Debloat-Windows/README.md) | Remove in-box applications |

---

## Shared prerequisites

| Requirement | Detail |
| --- | --- |
| PowerShell | 5.1 or later |
| Context | SYSTEM by default; some require a specific Windows edition |
| Console | Microsoft Intune admin center - Devices > Scripts |

---

## Related

- [ProactiveRemediations](../ProactiveRemediations/README.md) - detect-and-fix pairs
- [Win32Apps](../Win32Apps/README.md) - application packaging

---

[Back to repository root](../../../../README.md)
