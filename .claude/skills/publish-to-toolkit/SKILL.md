---
name: publish-to-toolkit
description: Publish a finished PowerShell script into this repository (powershell-toolkit) with its standard structure - correct domain placement, Verb-Noun naming, the mandatory ASCII header, a project README and CHANGELOG, category README update, verification, and a pull request. Use when a script is complete and should be added to the toolkit, or when the user invokes /publish-to-toolkit.
---

# Publish to powershell-toolkit

Takes a finished PowerShell script and lands it in this repository following its own
conventions. Never push to `main`; always open a PR. This skill is committed to the repo, so
it works from any Claude Code surface that opens it (CLI, desktop, or claude.ai/code).

The source of truth for conventions is [`docs/NAMING-CONVENTIONS.md`](../../../docs/NAMING-CONVENTIONS.md)
and [`docs/PROJECT-TEMPLATE.md`](../../../docs/PROJECT-TEMPLATE.md). This skill summarises them.

## 0. Preconditions

- `git` and `gh` installed and authenticated (`gh auth status`). `gh` may not be on PATH on
  Windows; it is typically at `C:\Program Files\GitHub CLI\gh.exe`.
- The repo cloned to a plain local folder, NOT inside OneDrive. Pull latest `main` first.
- Confirm with the user before starting - this opens a public PR.

## 1. Decide placement

Map the script to one domain and technology:

| Domain | Use for |
| --- | --- |
| `Azure/` | Azure resource automation, runbooks |
| `Endpoint/` | Intune, Windows 365 - device management via a management plane |
| `Identity/` | Active Directory, Entra ID, Microsoft Graph tooling |
| `Microsoft365/` | Exchange, SharePoint, Teams, tenant-wide |
| `Shared/` | Reusable across domains |
| `Virtualization/` | VMware / PowerCLI |
| `Windows/` | Scripts run directly on Windows (Server / Client / Common) |

Key distinctions: Intune-delivered management is `Endpoint/`, not `Windows/`. A Graph script
that manages a specific workload files under that workload, not `Identity/MicrosoftGraph/`. A
script that runs unmodified on server and workstation is `Windows/Common/`.

## 2. Branch

```
git checkout main && git pull
git checkout -b feat/<short-name>
```

## 3. Choose a tier

- **Tier 1** - single self-contained script. Files: `Verb-Noun.ps1`, `README.md`,
  `CHANGELOG.md`, `.gitignore`.
- **Tier 2** - reads config, ships more than one script, or writes logs. Adds `Config/`,
  `Docs/`, `Examples/`, `Tests/`, `Logs/`.

Start at Tier 1 and promote only when a folder would not ship empty. Copy the skeleton from
`_Template/Tier1-Standard/` or `_Template/Tier2-Full/`.

## 4. Place and name

- Project folder: PascalCase segments joined by a single hyphen (`PortGroup-Provisioning`).
- Script file: approved `Verb-Noun.ps1` (`Get-Verb`). Exceptions:
  `Microsoft.PowerShell_profile.ps1` and `*.Tests.ps1`. Intune detect/remediate pairs keep
  `Detect-`/`Remediate-`.
- No spaces in any path. No underscores in folder names.

## 5. Bring the script up to standard

- **ASCII only** in `.ps1` - convert emoji/smart quotes to bracketed markers (`[OK]`,
  `[WARN]`, `[FAIL]`).
- **Mandatory header** from `_Template/Tier1-Standard/Verb-Noun.ps1`: synopsis, description
  (including what it deliberately does NOT do), parameters, examples, notes, and the three
  remote-execution blocks with the correct raw URL for the new path.
- **No secrets or tenant data** - GUIDs, site tokens, tenant IDs, internal URLs become
  mandatory parameters. Never commit `.cred/.key/.pfx/.cer` or `.exe/.intunewin`.
- **Fix defects** - if it does not parse under Windows PowerShell 5.1 or has obvious bugs,
  fix them and record it in the CHANGELOG. Do not publish broken code silently.
- **Attribute third-party work** in the header and README; do not present it as original.

## 6. Docs

- `README.md` from the project template.
- `CHANGELOG.md` starting at `1.0.0`.
- Update the **parent category README's** project table.

## 7. Verify (all must pass)

```powershell
$e=$null; [System.Management.Automation.Language.Parser]::ParseFile('<path>.ps1',[ref]$null,[ref]$e); $e.Count   # 0
[System.IO.File]::ReadAllText('<path>.ps1') -match '[^\x00-\x7F]'   # False
git ls-files | Where-Object { $_ -match ' ' }   # empty
```

Confirm every relative markdown link resolves.

## 8. Commit, PR, clean up

```
git add -A
git commit -m "Add <project> to <Domain>"
git push -u origin feat/<short-name>
gh pr create --base main --head feat/<short-name> --title "..." --body-file <notes>
```

Review the diff, merge, then delete the branch (local + remote) and pull `main`. Never push
to `main` directly. Pin production consumers to a release tag, not `main`.

## Notes

- Copy scripts in fresh rather than grafting history from another repo - imported history can
  carry secrets or binaries.
- Cautionary tale: a hardcoded Datto RMM SiteID (a live tenant token) once sat in this
  public repo's history. Always parameterize tenant data.
