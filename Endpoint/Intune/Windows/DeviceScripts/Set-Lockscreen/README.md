# Intune - Device Scripts - Set Lockscreen

Sets, reverts, and detects the Windows lock screen and desktop background through the
Personalization CSP.

- 🖼️ Applies a lock screen and desktop background from URLs or local files
- ↩️ Reverts cleanly to the Windows default
- 🔍 Detection script for compliance or Win32 app detection
- 🔒 Enterprise / Education only - the CSP is ignored on Windows Pro

---

## Scripts

| Script | Purpose |
| --- | --- |
| [Set-Lockscreen.ps1](./Set-Lockscreen.ps1) | Applies the images and writes the CSP values |
| [Remove-Lockscreen.ps1](./Remove-Lockscreen.ps1) | Removes the CSP values, reverting to default |
| [Test-Lockscreen.ps1](./Test-Lockscreen.ps1) | Detection: reports whether the policy is fully applied |

### Requirements

| Requirement | Detail |
| --- | --- |
| PowerShell | 5.1 or later |
| Permissions | Elevated / SYSTEM for Set and Remove |
| Edition | Windows Enterprise or Education |

### Usage

```powershell
# From URLs
.\Set-Lockscreen.ps1 -BackgroundUrl "https://host/bg.jpg" -LockscreenUrl "https://host/lock.jpg"

# From local files shipped with the package
.\Set-Lockscreen.ps1 -BackgroundPath ".\bg.jpg" -LockscreenPath ".\lock.jpg"

# Revert
.\Remove-Lockscreen.ps1

# Detect (exit 0 = applied, exit 1 = not)
.\Test-Lockscreen.ps1
```

`Set-Lockscreen.ps1` uses parameter sets: supply **either** the two `-*Url` parameters
**or** the two `-*Path` parameters, not both.

---

## Safety features

- All three scripts verify elevation where they write
- `Set` and `Remove` support `-WhatIf`
- `Remove` skips values that are already absent
- Image staging is checked; a failed download or copy stops before any registry change

---

## Important scope notes

**The Personalization CSP is honoured on Windows Enterprise and Education only.** On Windows
Pro the registry values are written but ignored, so the policy applies cleanly and does
nothing. This is the single most common reason it "silently stops working". Confirm the
edition first.

`Remove-Lockscreen.ps1` removes the policy values but does not delete the staged image
files or restore a previous custom wallpaper; the device falls back to the Windows default.

`Test-Lockscreen.ps1` is read-only.

---

## Remote execution

See the header of any script for the supported invocation patterns.

> For production use, pin the URL to a release tag rather than `main`.

---

## Attribution

The Personalization CSP approach is based on the write-up at
<https://smbtothecloud.com/set-desktop-lock-screen-background>.

---

## Author

**Joel Cottrell** - [github.com/joelcottrell](https://github.com/joelcottrell)

## License

See [LICENSE](../../../../../LICENSE).

---

> Always test in a non-production environment first.
