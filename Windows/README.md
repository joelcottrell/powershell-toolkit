# Windows

Scripts run directly against a Windows operating system.

**Belongs here:** registry changes, networking traces, event log queries, certificate
operations, services, roles and features - anything an administrator runs on a machine.

**Does not belong here:** device management delivered through a management plane. Intune
compliance and remediation scripts live under [`Endpoint/`](../Endpoint/README.md), even
though they execute on Windows.

---

## Technologies

| Folder | Scope | |
| --- | --- | --- |
| Common | Runs unmodified on both server and workstation | [Browse](./Common/README.md) |
| Server | Server roles, features, and server-only surfaces | [Browse](./Server/README.md) |
| Client | Workstation-specific: shell, user experience, client apps | [Browse](./Client/README.md) |

### Choosing between them

**If a script runs unmodified on both, it goes in `Common/`.** That is the whole reason
`Common/` exists - without it, every OS-agnostic script becomes an arbitrary judgment call
and the split stops meaning anything.

Use `Server/` or `Client/` only when the script genuinely depends on one or the other: a
server role, or a workstation-only shell surface.

---

## Shared prerequisites

| Requirement | Detail |
| --- | --- |
| PowerShell | 5.1 or later |
| Permissions | Most scripts require an elevated session |

---

## Related

- [Endpoint](../Endpoint/README.md) - the same OS, managed through Intune
- [Identity](../Identity/README.md) - domain-joined machine and account management

---

[Back to repository root](../README.md)
