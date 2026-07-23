# Endpoint

Device management across every platform, independent of operating system.

Intune is a management plane covering Windows, macOS, iOS, and Android, so it does not
belong under `Windows/`. This parent leaves room for Autopilot, Defender for Endpoint, and
Configuration Manager alongside it.

**Belongs here:** anything that manages a device through a management plane - compliance
policies, remediation scripts, application packaging, enrolment, configuration profiles.

**Does not belong here:** scripts run directly on a machine by an administrator. Those go
to [`Windows/`](../Windows/README.md).

---

## Technologies

| Technology | Description | |
| --- | --- | --- |
| Intune | Compliance, proactive remediations, Win32 apps, device scripts | [Browse](./Intune/README.md) |

---

## Shared prerequisites

| Requirement | Detail |
| --- | --- |
| PowerShell | 5.1 or later |
| Permissions | Intune Administrator or equivalent for uploading policies and apps |
| Console | Microsoft Intune admin center |

Detection and remediation scripts run on the device in SYSTEM context by default. Where a
script requires user context, its README says so.

---

## Related

- [Windows](../Windows/README.md) - scripts run directly against an OS
- [Identity](../Identity/README.md) - Entra ID groups that target these policies

---

[Back to repository root](../README.md)
