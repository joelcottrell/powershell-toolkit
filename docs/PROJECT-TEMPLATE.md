# Project Template Guide

How to start a new project in this repository, and what every project owes its
reader.

Skeletons live in [`_Template/`](../_Template/README.md). This document explains
the reasoning behind them.

---

## Choosing a tier

| | Tier 1 - Standard | Tier 2 - Full |
| --- | --- | --- |
| Single self-contained script | Yes | |
| Reads external configuration | | Yes |
| More than one script | | Yes |
| Writes logs | | Yes |
| Has tests | | Yes |

**Start at Tier 1. Promote when the project earns it.**

If a Tier 2 folder would ship empty, you chose wrong. An empty `Tests/` reads as
abandonment, not ambition. A complete Tier 1 project is stronger than a hollow
Tier 2 one.

---

## Steps

1. Copy the tier folder to its destination domain, rename it per
   [NAMING-CONVENTIONS.md](./NAMING-CONVENTIONS.md).
2. Rename `Verb-Noun.ps1`. Check the verb with `Get-Verb`.
3. Fill in the script header, including the correct `<Domain>/<Technology>/<Project>`
   path in the three remote-execution blocks.
4. Write the README. Doing this before the script clarifies scope faster than
   code does.
5. Start `CHANGELOG.md` at `1.0.0`.
6. Add the project to its category README's project table.
7. Verify before committing:

```powershell
# Parses cleanly under Windows PowerShell 5.1
$errors = $null
[System.Management.Automation.Language.Parser]::ParseFile(
    '.\Verb-Noun.ps1', [ref]$null, [ref]$errors) | Out-Null
$errors.Count

# ASCII only
[System.IO.File]::ReadAllText('.\Verb-Noun.ps1') -match '[^\x00-\x7F]'

# No spaces in any path
git ls-files | Where-Object { $_ -match ' ' }
```

---

## The mandatory script header

Every `.ps1` carries comment-based help. **ASCII only, no Unicode.** The full
template is in
[`_Template/Tier1-Standard/Verb-Noun.ps1`](../_Template/Tier1-Standard/Verb-Noun.ps1).

Required sections: `.SYNOPSIS`, `.DESCRIPTION`, `.PARAMETER` for each parameter,
`.EXAMPLE`, `.NOTES` with file name, author, version, date, and requirements,
followed by the three remote-execution options.

### Why the header matters

It is not ceremony. `Get-Help .\Verb-Noun.ps1` works because of it, the
`.DESCRIPTION` is where scope boundaries get stated, and the remote-execution
block is the reason anyone can use the script without cloning the repository.

---

## Remote execution and its risks

Three patterns are documented in every header:

| Option | Pattern | Risk |
| --- | --- | --- |
| 1 | `Invoke-Expression` against a raw URL | Executes unreviewed remote code |
| 2 | Download, then run | Allows review first - **recommended** |
| 3 | Scheduled task that re-downloads each run | A repository compromise propagates immediately |

**Option 2 is the default recommendation.**

Option 1 is convenient for a public repository you control, and it is exactly
the pattern security teams flag. Option 3 compounds it: every run re-fetches, so
there is no window in which a bad change is caught before it executes.

### Pin production consumers to a tag

For anything touching production, replace `main` with a release tag:

```
https://raw.githubusercontent.com/joelcottrell/powershell-toolkit/v1.1/<path>/Verb-Noun.ps1
```

A branch changes under you. A tag does not. This is not optional advice for
scheduled tasks running as SYSTEM - it is the control that makes Option 3
defensible at all.

A related consideration: GitHub account renames release the old username, and
anyone may then claim it. Raw URLs built on a released username can be taken
over by a third party. Pinning to a tag inside a namespace you control, and
holding onto old namespaces you have abandoned, are both part of keeping this
pattern safe.

---

## What a project README owes its reader

Model on
[`PortGroup-Provisioning`](../Virtualization/VMware/PowerCLI/Networking/PortGroup-Provisioning/README.md),
the reference implementation.

1. Title: `<Technology> - <Project Name>`
2. Opening paragraph and capability bullets
3. Per-script: link, purpose, requirements, configuration, usage, existing-object behaviour
4. Project structure tree
5. Configuration review and confirmation, where interactive confirmation applies
6. Console progress
7. Logging
8. Safety features
9. **Important scope notes**
10. Testing
11. **Remote execution**
12. Additional documentation
13. Author
14. License
15. Footer: always test in non-production first

**Sections 9 and 11 are the two most valuable and the two most often skipped.**
Scope notes stop someone assuming the script does more than it does. Remote
execution is the entire reason the header convention exists.

---

## Never commit

- Credentials: `.cred`, `.key`, `.pfx`, `.cer`, `credentials.xml`
- Tenant identifiers: org GUIDs, site tokens, tenant IDs, subscription IDs
- Internal detail: corporate support addresses, phone numbers, internal URLs,
  partner portal links
- Live configuration: ship `<name>.example.csv`, never `<name>.csv`
- Binaries: `.exe`, `.intunewin`, `.nupkg`

Anything tenant-specific becomes a mandatory parameter. If a script cannot run
without a value, make the script demand it rather than shipping a default that
happens to be someone's real environment.

Note that `.gitignore` only helps for files you have not already committed, and
committing a secret means it stays in history even after removal. Rotate it.

---

[Back to repository root](../README.md)
