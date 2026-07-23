# Windows - Common

Scripts that run unmodified on both Windows Server and Windows client.

**Belongs here:** registry operations, network diagnostics, event log queries, certificate management, services, and scheduled tasks.

**Does not belong here:** anything depending on a server role or a workstation-only surface. Those go to [Server](../Server/README.md) or [Client](../Client/README.md).

When in doubt, ask whether the script would run unchanged on the other. If yes, it belongs
here. This folder exists precisely so that OS-agnostic scripts have an obvious home rather
than being filed by coin toss.

---

## Projects

| Project | Description | Tier |
| --- | --- | --- |
| [Netsh](./Netsh/README.md) | Captures consecutive timed netsh network traces and compresses each result | 1 |

---

## Shared prerequisites

| Requirement | Detail |
| --- | --- |
| PowerShell | 5.1 or later |
| Permissions | Elevated session for most operations |

---

## Related

- [Server](../Server/README.md) - server-specific
- [Client](../Client/README.md) - workstation-specific
- [Endpoint](../../Endpoint/README.md) - the same OS, managed through Intune

---

[Back to repository root](../../README.md)