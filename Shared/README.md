# Shared

Code reused across domains rather than belonging to any one of them.

**Belongs here:** helper functions, modules, and tooling that more than one domain depends
on, plus environment configuration like the managed PowerShell profile.

**Does not belong here:** anything a single domain owns. If only the VMware scripts use it,
it lives with the VMware scripts. Premature sharing is worse than duplication - move code
here when a second consumer actually appears.

---

## Projects

| Project | Description | Tier |
| --- | --- | --- |
| [PowerShell-Profile](./PowerShell-Profile/README.md) | Centrally managed profile and its bootstrap loader | 1 |

---

## Shared prerequisites

| Requirement | Detail |
| --- | --- |
| PowerShell | 5.1 or later |
| Permissions | None beyond the user's own profile |

---

## A note on the profile bootstrap

The profile loader deliberately performs **no network access at shell start**. An earlier
version downloaded and executed a script from a raw GitHub URL on every session, which
meant every new shell ran whatever that URL returned, unpinned and unverified.

It now loads a local cache and updates only when asked, with SHA256 verification. If you
are adapting this pattern for your own use, read
[the security model](./PowerShell-Profile/README.md#security-model) before you do.

---

## Related

- [_Template](../_Template/README.md) - skeletons for new projects
- [docs/PROJECT-TEMPLATE.md](../docs/PROJECT-TEMPLATE.md) - conventions for shared code

---

[Back to repository root](../README.md)
