# Intune - Win32 Apps - Zoom

Silently removes the per-user Zoom desktop client across every profile on a device.

- 🗑️ Removes Zoom for every user profile, not just the one running the script
- 🛑 Stops the running process before deleting files
- 🧹 Removes the app folder, per-user uninstall key, and Start Menu shortcut
- 📄 Writes a detection marker for Intune file-exists detection

---

## Uninstall-Zoom.ps1

[Uninstall-Zoom.ps1](./Uninstall-Zoom.ps1)

The Zoom client installs per user under each profile's AppData rather than machine-wide, so
a single uninstall leaves it behind for everyone else. This script walks every profile and
removes Zoom from each one that has it.

### Requirements

| Requirement | Detail |
| --- | --- |
| PowerShell | 5.1 or later |
| Permissions | Elevated / SYSTEM. Deploy as a Win32 app in system context |
| Detection | File exists: `%ProgramData%\Intune-Zoom-Uninstall\Output.txt` |

### Usage

```powershell
# Remove Zoom for every profile
.\Uninstall-Zoom.ps1

# Report which profiles have Zoom, without removing anything
.\Uninstall-Zoom.ps1 -WhatIf
```

### Existing object behaviour

Profiles without Zoom are reported and skipped. Safe to re-run: a second run finds nothing
to remove and completes cleanly.

---

## Safety features

- Verifies elevation and exits if not elevated
- Supports `-WhatIf`
- Skips the built-in `Public`, `Default`, and `All Users` profiles
- Unmaps the temporary `HKU:` drive in a `finally` block even if a removal throws

---

## Important scope notes

Handles the standard **per-user** Zoom install (the `ZoomUMX` uninstall key). It does
**not** remove the separate **machine-wide** Zoom MSI. If your environment deploys that
build, uninstall it through its own product code in addition to running this.

Removing the Start Menu shortcut and AppData folder does not revoke any Zoom SSO session or
account; it only removes the client binaries and their per-user registration.

---

## Remote execution

See the header of [Uninstall-Zoom.ps1](./Uninstall-Zoom.ps1) for the three supported
invocation patterns.

> Downloading and reviewing before running is the recommended pattern. For production use,
> pin the URL to a release tag rather than `main`.

---

## Attribution

The per-user removal approach was adapted from a community SCCM discussion, linked in the
script header.

---

## Author

**Joel Cottrell** - [github.com/joelcottrell](https://github.com/joelcottrell)

## License

See [LICENSE](../../../../../LICENSE).

---

> Always test in a non-production environment first.
