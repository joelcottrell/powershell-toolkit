# Virtualization - VMware

vSphere automation via PowerCLI.

**Belongs here:** vCenter and ESXi management - hosts, networking, virtual machines,
authentication, and reporting.

**Does not belong here:** the guest OS inside a VM. That is [`Windows/`](../../Windows/README.md).

---

## Technologies

| Technology | Description | |
| --- | --- | --- |
| PowerCLI | vSphere automation module | [Browse](./PowerCLI/README.md) |

---

## Shared prerequisites

| Requirement | Detail |
| --- | --- |
| PowerShell | 5.1 or later |
| Module | `VMware.PowerCLI` 13 or later |
| Permissions | vCenter credentials with rights appropriate to the task |

```powershell
Install-Module VMware.PowerCLI -Scope CurrentUser
```

If your vCenter uses a self-signed certificate:

```powershell
Set-PowerCLIConfiguration -Scope User -InvalidCertificateAction Ignore -Confirm:$false
```

Understand what that setting disables before using it outside a lab.

---

## Related

- [Identity](../../Identity/README.md) - external identity providers for vCenter
- [Windows](../../Windows/README.md) - guest OS administration

---

[Back to repository root](../../README.md)
