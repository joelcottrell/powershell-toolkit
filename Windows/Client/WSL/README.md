# Windows Client - WSL

Install, remove, and toggle Windows Subsystem for Linux on a workstation.

- ✅ Installs WSL and Ubuntu in one operation
- 🔄 Toggles the WSL optional feature independently of any distribution
- 🗑️ Removes the distribution, the kernel update, and the feature
- 🛡️ Confirms before destroying a distribution filesystem
- ⏱️ Schedules the restart each operation requires, and lets you decline it

---

## Scripts

| Script | Purpose |
| --- | --- |
| [Install-WSL2Ubuntu.ps1](./Install-WSL2Ubuntu.ps1) | Installs WSL with the Ubuntu distribution, then restarts |
| [Uninstall-WSL2Ubuntu.ps1](./Uninstall-WSL2Ubuntu.ps1) | Removes Ubuntu, the WSL update, and the feature, then restarts |
| [Set-WSLFeature.ps1](./Set-WSLFeature.ps1) | Enables or disables the WSL optional feature only |

### Requirements

| Requirement | Detail |
| --- | --- |
| PowerShell | 5.1 or later |
| OS | Windows 10 2004 or later, or Windows 11 |
| Permissions | Elevated session. Each script checks and exits if not elevated |

### Usage

```powershell
# Install WSL and Ubuntu, restart after 60 seconds
.\Install-WSL2Ubuntu.ps1

# Install but leave the restart to you
.\Install-WSL2Ubuntu.ps1 -NoRestart

# Toggle the feature only, without touching any distribution
.\Set-WSLFeature.ps1 -State Enabled

# Preview a removal without changing anything
.\Uninstall-WSL2Ubuntu.ps1 -WhatIf
```

| Parameter | Applies to | Description |
| --- | --- | --- |
| `-RestartDelaySeconds` | Install, Uninstall | Seconds before restart. Default 60 |
| `-NoRestart` | Install, Uninstall | Skip the restart entirely |
| `-Distribution` | Uninstall | Distribution to remove. Default `ubuntu` |
| `-Force` | Uninstall | Skip the confirmation prompt |
| `-State` | Set-WSLFeature | `Enabled` or `Disabled` |

### Existing object behaviour

`Install-WSL2Ubuntu.ps1` is safe to re-run: `wsl --install` is a no-op when WSL and the
distribution are already present.

`Uninstall-WSL2Ubuntu.ps1` continues past components that are already gone. A missing AppX
package or an already-disabled feature is reported and skipped rather than treated as an
error.

---

## Safety features

- Every script verifies elevation and exits rather than failing halfway through
- All three support `-WhatIf`
- The uninstall prompts before destroying a filesystem, and its `ConfirmImpact` is `High`
- The install checks `wsl --install` exit code and will not schedule a restart if it failed
- Restarts are scheduled, not immediate; `shutdown /a` aborts within the delay

---

## Important scope notes

**Uninstalling destroys data.** `wsl --unregister` permanently deletes the distribution's
filesystem. Home directories, installed packages, and anything not copied out are gone and
are not recoverable from Windows. Copy work out first.

These scripts deliberately do **not**:

- Set a default distribution, install packages inside it, or create the initial UNIX user.
  Ubuntu prompts for that account on first launch.
- Remove distributions other than the one named.
- Touch the Virtual Machine Platform feature, which Hyper-V, Docker Desktop, and Windows
  Sandbox also depend on. Disabling it here would break them.
- Remove the Windows Terminal profile left behind by the distribution.

**A restart is mandatory.** WSL cannot finish enabling or disabling its optional features
until the machine reboots. Using `-NoRestart` leaves the operation half-applied until a
restart happens by some other means.

---

## Remote execution

See the header of any script for the three supported invocation patterns.

> Downloading and reviewing before running is the recommended pattern, and doubly so for
> `Uninstall-WSL2Ubuntu.ps1`, which destroys data. For production use, pin the URL to a
> release tag rather than `main`.

---

## Attribution

`Set-WSLFeature.ps1` was originally written by **David Brook**. It is retained and
corrected here rather than presented as original work.

---

## Author

**Joel Cottrell** - [github.com/joelcottrell](https://github.com/joelcottrell)

## License

See [LICENSE](../../../LICENSE).

---

> Always test in a non-production environment first.
