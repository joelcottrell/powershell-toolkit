# Identity

Directory services, identity platforms, and the tooling that spans them.

**Belongs here:** users, groups, devices as directory objects, authentication, conditional
access, app registrations, and directory-wide reporting.

**Does not belong here:** a workload that happens to be reached via an identity API. A
Graph script that manages mailboxes is an Exchange script - it goes to
[`Microsoft365/Exchange/`](../Microsoft365/README.md).

---

## Technologies

| Technology | Description | |
| --- | --- | --- |
| Active Directory | On-premises directory administration | [Browse](./ActiveDirectory/README.md) |
| Entra ID | Cloud identity, conditional access | [Browse](./EntraID/README.md) |
| Microsoft Graph | Graph-centric tooling | [Browse](./MicrosoftGraph/README.md) |

### On Microsoft Graph

`MicrosoftGraph/` is for tooling where Graph itself is the subject: authentication helpers,
app registration management, permission auditing, generic query wrappers.

Where Graph is merely the transport to manage a specific workload, file the script under
that workload instead. The test is simple - if you replaced Graph with a different API and
the script's purpose stayed the same, it belongs with the workload, not here.

---

## Shared prerequisites

| Requirement | Detail |
| --- | --- |
| PowerShell | 5.1 or later |
| Modules | `ActiveDirectory` (RSAT) for on-premises; `Microsoft.Graph` for cloud |
| Permissions | Vary by task - each project README states its own |

Grant Graph permissions at the least scope that works. Read-only reporting should not be
running with write consent.

---

## Related

- [Microsoft365](../Microsoft365/README.md) - workloads these identities access
- [Endpoint](../Endpoint/README.md) - Entra ID groups that target Intune policies

---

[Back to repository root](../README.md)
