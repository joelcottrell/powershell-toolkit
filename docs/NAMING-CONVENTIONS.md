# Naming Conventions

These rules are non-negotiable. They exist because this repository is consumed
over raw GitHub URLs, and inconsistent naming breaks that consumption in ways
that fail silently.

---

## Rules

| Element | Rule | Example |
| --- | --- | --- |
| Folder names | PascalCase, no spaces, no underscores | `ActiveDirectory` |
| Category folders | PascalCase, concatenated | `ProactiveRemediations` |
| Project folders | PascalCase segments joined by a single hyphen | `PortGroup-Provisioning` |
| Script files | PowerShell approved `Verb-Noun.ps1` | `New-DistributedPortGroups.ps1` |
| README files | Always exactly `README.md` | not `README.MD`, not `Readme.md` |
| Changelog files | Always exactly `CHANGELOG.md` | |
| Vendor casing | Match the vendor | `VMware`, `PowerCLI`, `Microsoft365`, `EntraID` |
| Reserved prefix | `_` prefixes sort-first meta folders only | `_Template` |
| Config samples | `<name>.example.csv`, never a live `<name>.csv` | `portgroups.example.csv` |

### Category or project?

A **category** folder groups other folders and holds no scripts of its own. It
uses concatenated PascalCase: `ProactiveRemediations`, `DeviceScripts`,
`SecurityBaselines`, `WindowsUpdate`.

A **project** folder holds scripts. It uses hyphenated segments:
`Disable-WindowsFastBoot`, `Create-LocalAdminAccount`, `Cisco-Umbrella`.

The distinction is not cosmetic. It lets you tell from a URL alone whether you
are looking at a grouping or at something runnable.

---

## The spaces rule

**No spaces. Anywhere. Ever.**

Every script in this repository carries a remote-execution header built on
`raw.githubusercontent.com`. A folder named `Azure Runbook` becomes
`Azure%20Runbook` in that URL. Percent-encoded paths do work, but they:

- break copy-paste between browser, terminal, and documentation
- break shell quoting inside scheduled task arguments
- fail silently rather than loudly, which is the worst way to fail

This repository previously had 55 space-bearing paths. They are gone and they do
not come back.

---

## Verbs

Use an approved PowerShell verb. Check with:

```powershell
Get-Verb
```

Common correct choices for this repository:

| Intent | Verb |
| --- | --- |
| Detect a condition (Intune detection scripts) | `Detect` is not approved - use `Test` or `Get`, or keep `Detect` only where Intune requires the pairing |
| Fix a condition (Intune remediation scripts) | `Remediate` likewise - retained for Intune's Detect/Remediate pairing |
| Create something | `New` |
| Remove something | `Remove` |
| Install software | `Install` |
| Change existing state | `Set` |
| Retrieve data | `Get` |
| Begin a process | `Start` |

`Detect-` and `Remediate-` are deliberate exceptions. Intune's proactive
remediations pair a detection script with a remediation script, and matching
that platform vocabulary is worth more here than strict `Get-Verb` compliance.
Everywhere else, use an approved verb.

---

## Exceptions

Two files are exempt, both for external reasons:

| File | Why |
| --- | --- |
| `Microsoft.PowerShell_profile.ps1` | PowerShell requires this exact filename for `$PROFILE`. |
| `*.Tests.ps1` | Pester discovers tests by this suffix. |

Neither is a precedent. If you think you have a third exception, you probably
have a naming problem instead.

---

## Casing traps on Windows

NTFS is case-insensitive, so `git mv README.MD README.md` fails or silently
no-ops. Use the two-step form:

```powershell
git mv README.MD README.tmp
git mv README.tmp README.md
```

Or force it:

```powershell
git mv -f README.MD README.md
```

Verify with a case-sensitive check:

```powershell
git ls-files | Where-Object { $_ -cmatch 'README\.MD$' }
```

---

## Content rules

- **ASCII only in `.ps1` and `.cmd` files.** Markdown may use emoji; scripts may
  not. Console encoding varies across hosts and emoji render as mojibake often
  enough to be a real problem.
- **No hardcoded tenant data.** No org GUIDs, site tokens, tenant IDs, internal
  URLs, support addresses, or phone numbers. Make them mandatory parameters.
- **No credentials, ever.** `.cred`, `.key`, `.pfx`, and `.cer` are gitignored,
  but the ignore file is a safety net, not a control.
- **No binaries.** `.exe` and `.intunewin` are build artifacts. Build them, do
  not commit them.

---

[Back to repository root](../README.md)
