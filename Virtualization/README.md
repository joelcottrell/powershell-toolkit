# Virtualization

Hypervisor and virtual infrastructure automation.

**Belongs here:** anything managing a hypervisor, its hosts, its networking, or the virtual
machines running on it.

**Does not belong here:** the guest operating system inside a VM. Once you are configuring
Windows itself, you are in [`Windows/`](../Windows/README.md), regardless of whether the
machine is virtual.

---

## Technologies

| Technology | Description | |
| --- | --- | --- |
| VMware | vSphere and PowerCLI automation | [Browse](./VMware/README.md) |

Structured to accommodate Nutanix and Hyper-V as siblings without reorganising.

---

## Shared prerequisites

| Requirement | Detail |
| --- | --- |
| PowerShell | 5.1 or later |
| Module | `VMware.PowerCLI` - `Install-Module VMware.PowerCLI -Scope CurrentUser` |
| Permissions | vCenter credentials with rights appropriate to the task |

---

## Related

- [Windows](../Windows/README.md) - guest OS administration
- [Identity](../Identity/README.md) - external identity providers for vCenter authentication

---

[Back to repository root](../README.md)
