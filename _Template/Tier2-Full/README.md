# \<Technology\> - \<Project Name\>

One paragraph on what this project does and who it is for.

- ✅ Capability one
- 🔍 Capability two
- 📊 Capability three
- 📝 Capability four

---

## \<Verb-Noun.ps1\>

[Verb-Noun.ps1](./Verb-Noun.ps1)

What the script does, in two or three sentences.

### Requirements

| Requirement | Detail |
| --- | --- |
| PowerShell | 5.1 or later |
| Modules | `<module names>` |
| Permissions | `<role or rights needed>` |

### Configuration

Copy the example and edit it:

```powershell
Copy-Item .\Config\settings.example.csv .\Config\settings.csv
```

The working copy is ignored by git; the example is tracked. Full schema in
[Docs/Reference.md](./Docs/Reference.md).

### Usage

```powershell
.\Verb-Noun.ps1 -ParameterName "value"
```

| Parameter | Required | Description |
| --- | --- | --- |
| `-ParameterName` | Yes | What it controls. |

### Existing object behaviour

State what happens when the target already exists: skipped, updated, or failed.

---

## Project structure

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
|-- CHANGELOG.md
|-- README.md
`-- .gitignore
```

---

## Configuration review and confirmation

If the script prompts before making changes, show what that prompt looks like
and what each response does.

## Console progress

What the operator sees while it runs.

## Logging

Logs are written to `Logs/` with a timestamped filename. The directory is
ignored by git apart from its `.gitkeep` placeholder.

## Safety features

- Supports `-WhatIf`
- Validates configuration before making any change
- Idempotent: re-running produces no additional changes

---

## Important scope notes

What this script deliberately does **not** do. Be explicit.

---

## Testing

```powershell
Invoke-Pester .\Tests\Project.Tests.ps1
```

---

## Remote execution

See the header of [Verb-Noun.ps1](./Verb-Noun.ps1) for the three supported
invocation patterns.

> Downloading and reviewing before running is the recommended pattern. For
> production use, pin the URL to a release tag rather than `main`.

---

## Additional documentation

- [Operational Notes](./Docs/Operational-Notes.md)
- [Reference](./Docs/Reference.md)
- [Usage Examples](./Examples/Usage-Examples.ps1)

---

## Author

**Joel Cottrell** - [github.com/joelcottrell](https://github.com/joelcottrell)

## License

See [LICENSE](../../LICENSE).

---

> Always test in a non-production environment first.
