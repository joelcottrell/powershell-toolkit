# Microsoft 365

Workload administration across the Microsoft 365 service family.

**Belongs here:** anything scoped to a specific workload - mailboxes, sites, teams - plus
tenant-wide concerns that cross all of them.

**Does not belong here:** the identities that access these workloads. Users, groups, and
conditional access live under [`Identity/`](../Identity/README.md).

---

## Technologies

| Technology | Description | |
| --- | --- | --- |
| Exchange | Exchange Online and on-premises | [Browse](./Exchange/README.md) |
| SharePoint | SharePoint Online administration | [Browse](./SharePoint/README.md) |
| Teams | Teams administration and policy | [Browse](./Teams/README.md) |
| Tenant | Licensing, service health, cross-workload reporting | [Browse](./Tenant/README.md) |

### When to use Tenant

`Tenant/` is for anything genuinely tenant-wide: licence assignment and reporting, service
health, tenant configuration, and reporting that spans more than one workload.

If a script touches exactly one workload, file it under that workload even when it is
reached through a tenant-level API.

---

## Shared prerequisites

| Requirement | Detail |
| --- | --- |
| PowerShell | 5.1 or later |
| Modules | `ExchangeOnlineManagement`, `Microsoft.Online.SharePoint.PowerShell`, `MicrosoftTeams`, `Microsoft.Graph` |
| Permissions | Workload-specific administrator roles |

Connect with the least-privileged role that completes the task, and disconnect when done -
several of these modules hold a session open.

---

## Related

- [Identity](../Identity/README.md) - the accounts and groups behind these workloads
- [Endpoint](../Endpoint/README.md) - device-side policy for Microsoft 365 apps

---

[Back to repository root](../README.md)
