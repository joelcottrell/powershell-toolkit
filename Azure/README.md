# Azure

Azure resource automation and cloud-hosted runbooks.

**Belongs here:** Azure resource management, Automation Account runbooks, and anything
executing in Azure rather than against it from a workstation.

**Does not belong here:** Entra ID. Despite the shared portal, identity is a separate
domain and lives under [`Identity/EntraID/`](../Identity/README.md).

---

## Technologies

| Technology | Description | |
| --- | --- | --- |
| Automation | Azure Automation runbooks | [Browse](./Automation/README.md) |

---

## Shared prerequisites

| Requirement | Detail |
| --- | --- |
| PowerShell | 5.1 or later |
| Modules | `Az` - `Install-Module Az -Scope CurrentUser` |
| Permissions | Azure RBAC role appropriate to the resources touched |

Runbooks authenticate with a managed identity rather than stored credentials. If a script
here asks you to paste a secret, it is wrong - raise an issue.

---

## Related

- [Identity](../Identity/README.md) - Entra ID and app registrations
- [Microsoft365](../Microsoft365/README.md) - tenant administration

---

[Back to repository root](../README.md)
