# _Template

Starting skeletons for new script projects. Copy one, rename it, and fill it in.
Every new project in this repository begins here so that structure, headers, and
documentation are consistent rather than reinvented each time.

The leading underscore sorts this folder to the top and marks it as meta rather
than content. It is the only folder in the repository allowed that prefix.

---

## Which tier?

| | Tier 1 - Standard | Tier 2 - Full |
| --- | --- | --- |
| A single self-contained script | Yes | |
| Reads external configuration | | Yes |
| Ships more than one script | | Yes |
| Writes log files | | Yes |
| Has tests | | Yes |

**Start at Tier 1 and promote when the project earns it.**

If a folder in the Tier 2 skeleton would ship empty, you picked the wrong tier.
An empty `Tests/` or `Config/` folder does not read as thorough, it reads as
abandoned. A clean Tier 1 project is better than a hollow Tier 2 one.

---

## Tier 1 - Standard

```
Project-Name/
|-- Verb-Noun.ps1
|-- README.md
|-- CHANGELOG.md
`-- .gitignore
```

## Tier 2 - Full

Mirrors the layout of `Virtualization/VMware/PowerCLI/Networking/PortGroup-Provisioning`,
which is the reference implementation for this tier.

```
Project-Name/
|-- Verb-Noun.ps1
|-- Config/
|   `-- settings.example.csv
|-- Docs/
|   |-- Operational-Notes.md
|   `-- Reference.md
|-- Examples/
|   `-- Usage-Examples.ps1
|-- Tests/
|   `-- Project.Tests.ps1
|-- Logs/
|   `-- .gitkeep
|-- CHANGELOG.md
|-- README.md
`-- .gitignore
```

---

## Using a skeleton

1. Copy the tier folder to its destination domain and rename it. Project folder
   names are PascalCase segments joined by a single hyphen - `PortGroup-Provisioning`.
2. Rename `Verb-Noun.ps1` to an approved PowerShell verb and a singular noun.
   Check yours with `Get-Verb`.
3. Fill in the script header. It is mandatory, and it is ASCII only.
4. Write the README before writing the script if you can. It clarifies scope
   faster than code does.
5. Start `CHANGELOG.md` at `1.0.0`.
6. Add the project to its category README's project table.

See [NAMING-CONVENTIONS.md](../docs/NAMING-CONVENTIONS.md) for the full rules and
[PROJECT-TEMPLATE.md](../docs/PROJECT-TEMPLATE.md) for the header and README
templates in full.

---

## Non-negotiables

- **No spaces in any path.** Every script here is served over
  `raw.githubusercontent.com`. A space becomes `%20`, which breaks copy-paste,
  breaks shell quoting in scheduled tasks, and fails silently.
- **ASCII only in scripts.** Markdown may use emoji; `.ps1` files may not.
- **Configuration ships as `<name>.example.csv`**, never as a live file. The
  repository `.gitignore` tracks the example and ignores the working copy.
- **Never commit credentials.** No `.cred`, `.key`, `.pfx`, or `.cer`, and no
  tenant identifiers, site tokens, or org GUIDs hardcoded in a script. Make them
  mandatory parameters instead.

---

[Back to repository root](../README.md)
