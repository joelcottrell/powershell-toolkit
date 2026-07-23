# Endpoint - Windows 365

Windows 365 Cloud PC administration.

**Belongs here:** Cloud PC provisioning, configuration, lifecycle, and anything specific to
the Windows 365 service.

**Does not belong here:** general Windows configuration that happens to be applied to a
Cloud PC. If the script would work identically on a physical machine, it belongs under
[`Windows/`](../../Windows/README.md).

Cloud PCs are also Intune-managed devices, so policy delivered through Intune belongs under
[`Intune/`](../Intune/README.md). This folder is for the Windows 365 service layer itself.

---

## Projects

| Project | Description | Tier |
| --- | --- | --- |
| [NonAdminRestart](./NonAdminRestart/README.md) | Lets standard users restart a Cloud PC without administrative rights | 1 |

---

## Shared prerequisites

| Requirement | Detail |
| --- | --- |
| PowerShell | 5.1 or later |
| Permissions | Elevated session for device-local scripts; Windows 365 administrative roles for service-level scripts |
| Modules | `Microsoft.Graph` for anything touching the Windows 365 service via Graph |

---

## Related

- [Intune](../Intune/README.md) - policy and applications delivered to Cloud PCs
- [Identity](../../Identity/README.md) - the accounts and groups Cloud PCs are assigned to
- [Windows](../../Windows/README.md) - OS administration that is not Cloud PC specific

---

[Back to repository root](../../README.md)
