# VMware - PowerCLI

vSphere automation using the VMware PowerCLI module.

**Belongs here:** anything driving vCenter or ESXi through PowerCLI - hosts, networking,
virtual machines, authentication, and reporting.

**Does not belong here:** the guest operating system inside a VM. That is
[`Windows/`](../../../Windows/README.md), virtual or not.

---

## Categories

| Category | Description | |
| --- | --- | --- |
| Authentication | Connecting to vCenter, including external identity providers | [Browse](./Authentication/README.md) |
| Networking | vSwitches, distributed switches, and port groups | [Browse](./Networking/README.md) |
| Hosts | ESXi host configuration and lifecycle | [Browse](./Hosts/README.md) |
| VirtualMachines | VM lifecycle, provisioning, and configuration | [Browse](./VirtualMachines/README.md) |
| Reporting | Read-only inventory and audit reporting | [Browse](./Reporting/README.md) |

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

### Configuration

Suppress the CEIP prompt on first run:

```powershell
Set-PowerCLIConfiguration -Scope User -ParticipateInCEIP $false -Confirm:$false
```

If your vCenter presents a self-signed certificate:

```powershell
Set-PowerCLIConfiguration -Scope User -InvalidCertificateAction Ignore -Confirm:$false
```

That second setting disables certificate validation for every PowerCLI connection from
that account. Understand what you are turning off before using it outside a lab.

---

## Related

- [Authentication](./Authentication/README.md) - start here if you cannot connect
- [Identity](../../../Identity/README.md) - the identity providers behind federated logins

---

## Disclaimer

Understand the impact of each script before running it. Test in a non-production
environment first.

---

[Back to repository root](../../../README.md)
