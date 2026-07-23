# VMware PowerCLI - Networking

vSphere networking automation: standard switches, distributed switches, and port groups.

**Belongs here:** vSwitches, port groups, VMkernel adapters, uplinks, and network policy on
hosts or distributed switches.

**Does not belong here:** guest OS networking. Configuring an adapter inside Windows is
[`Windows/Common/`](../../../../Windows/Common/README.md).

---

## Projects

| Project | Description | Tier |
| --- | --- | --- |
| [PortGroup-Provisioning](./PortGroup-Provisioning/README.md) | Creates standard vSwitches, standard port groups, and distributed port groups from validated CSV | 2 |

---

## Shared prerequisites

| Requirement | Detail |
| --- | --- |
| PowerShell | 5.1 or later |
| Module | `VMware.PowerCLI` 13 or later |
| Permissions | vCenter rights to create and modify port groups and vSwitches |

---

## Related

- [Hosts](../Hosts/README.md) - ESXi host configuration
- [Authentication](../Authentication/README.md) - connecting to vCenter

---

[Back to repository root](../../../../README.md)
