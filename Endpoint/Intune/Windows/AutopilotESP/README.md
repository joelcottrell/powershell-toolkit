# Intune - Windows - Autopilot ESP

Scripts scoped to the Windows Autopilot Enrollment Status Page (ESP) phase.

The ESP runs during Autopilot provisioning, before a real user signs in. Detecting that
phase lets an app run once during provisioning rather than on every device afterwards.

---

## Scripts

| Script | Purpose |
| --- | --- |
| [Get-EspDetectionOption.ps1](./Get-EspDetectionOption.ps1) | Requirement rule that returns True only while the device is in the ESP phase |

### Requirements

| Requirement | Detail |
| --- | --- |
| PowerShell | 5.1 or later |
| Use | Intune Win32 app requirement rule, string output, expected value `True` |

### How it works

During the ESP the interactive shell runs as `defaultuser0` (or `defaultuser1`). The script
checks the owner of each `explorer.exe` and writes `True` when one of those accounts is
present, `False` otherwise. As an Intune requirement rule, the associated app installs only
when the rule returns `True`.

---

## Important scope notes

This is a **read-only detection script**. It changes nothing on the device.

It pairs with the **UpdateOS** app by Michael Niehaus (third party,
<https://github.com/mtniehaus/UpdateOS>), which is not included in this repository. Install
UpdateOS from its own source and use this script as its requirement rule.

The `defaultuser0`/`defaultuser1` convention is an Autopilot implementation detail, not a
documented contract. Revalidate it against new Windows builds before relying on it in
production.

---

## Remote execution

See the header of [Get-EspDetectionOption.ps1](./Get-EspDetectionOption.ps1) for the three
supported invocation patterns.

> For production use, pin the URL to a release tag rather than `main`.

---

## Author

**Joel Cottrell** - [github.com/joelcottrell](https://github.com/joelcottrell)

## License

See [LICENSE](../../../../LICENSE).

---

> Always test in a non-production environment first.
