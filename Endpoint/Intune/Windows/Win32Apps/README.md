# Intune - Windows - Win32 Apps

Windows Win32 application packages deployed through Microsoft Intune: installers,
uninstallers, and their detection rules.

---

## Projects

| Project | Description |
| --- | --- |
| [Azul-Zulu-OpenJRE](./Azul-Zulu-OpenJRE/README.md) | Install and uninstall the Azul Zulu OpenJRE runtime |
| [Datto-RMM](./Datto-RMM/README.md) | Install and uninstall the Datto RMM agent |
| [SnagIT-2024](./SnagIT-2024/README.md) | Install and uninstall Snagit 2024 |
| [Zoom](./Zoom/README.md) | Silently uninstall the per-user Zoom client across all profiles |

---

## Structure

```
Win32Apps/
├── Azul-Zulu-OpenJRE/
├── Datto-RMM/
│   ├── Windows/
│   └── macOS/
├── SnagIT-2024/
└── Zoom/
```

---

## Shared prerequisites

| Requirement | Detail |
| --- | --- |
| PowerShell | 5.1 or later |
| Context | System context by default; deploy as a Win32 app |
| Detection | Each project documents its own detection rule |

---

## Related

- [ProactiveRemediations](../ProactiveRemediations/README.md) - detect-and-fix pairs
- [DeviceScripts](../DeviceScripts/README.md) - platform scripts that run once

---

[Back to repository root](../../../../README.md)
