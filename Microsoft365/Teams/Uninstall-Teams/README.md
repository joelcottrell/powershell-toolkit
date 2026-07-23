# Microsoft 365 - Teams - Uninstall Teams

Removes the classic Microsoft Teams client and its machine-wide installer.

- 🗑️ Removes the Teams Machine-Wide Installer (MSI)
- 👤 Removes the current user's classic Teams client
- 🔁 Idempotent - reports and skips whatever is already gone
- ⚡ Locates the MSI by name rather than enumerating every installed product

---

## Uninstall-Teams.ps1

[Uninstall-Teams.ps1](./Uninstall-Teams.ps1)

The classic Teams client installs per user and reinstalls itself from the machine-wide
installer at each logon. Removing the client alone is not enough; the machine-wide
installer has to go too, which is why this does both.

### Requirements

| Requirement | Detail |
| --- | --- |
| PowerShell | 5.1 or later |
| Permissions | Elevation for the machine-wide installer. Without it, only the user client is removed |

### Usage

```powershell
# Remove the machine-wide installer and the current user's client
.\Uninstall-Teams.ps1

# Remove only the current user's client
.\Uninstall-Teams.ps1 -SkipMachineWide

# Preview without changing anything
.\Uninstall-Teams.ps1 -WhatIf
```

### Existing object behaviour

Safe to re-run. A missing machine-wide installer or user client is reported and skipped
rather than treated as an error.

---

## Safety features

- Supports `-WhatIf`
- Warns and continues with user-only removal when not elevated, instead of failing
- Queries the MSI provider by name rather than enumerating `Win32_Product`, which avoids
  the consistency check that class triggers against every installed product
- Checks the MSI and updater exit codes rather than assuming success

---

## Important scope notes

**Classic Teams (1.0) only.** This targets the per-user classic client and its machine-wide
MSI. It does **not** remove **new Teams (2.x)**, which ships as an MSIX package serviced by
the Store. Remove that with `Get-AppxPackage` and `Remove-AppxProvisionedPackage` instead.

It removes the client binaries and registration only. It does not sign the user out of
Microsoft 365 or clear cached credentials.

---

## Remote execution

See the header of [Uninstall-Teams.ps1](./Uninstall-Teams.ps1) for the supported invocation
patterns.

> Downloading and reviewing before running is the recommended pattern. For production use,
> pin the URL to a release tag rather than `main`.

---

## Author

**Joel Cottrell** - [github.com/joelcottrell](https://github.com/joelcottrell)

## License

See [LICENSE](../../../LICENSE).

---

> Always test in a non-production environment first.
