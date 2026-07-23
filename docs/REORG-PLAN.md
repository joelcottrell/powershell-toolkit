# Repository Rearchitecture Plan

**Repository:** `bigjoestretch/powershell-toolkit` (now `joelcottrell/powershell-toolkit`)
**Author:** Joel Cottrell
**Plan version:** 1.0
**Status:** Executed

---

> ## ⚠️ Historical document
>
> This is the plan **as approved before execution**, retained as a record of the reasoning
> behind the current structure. It is not maintained and should not be followed as
> instructions.
>
> Two things changed during execution:
>
> 1. **The GitHub account was renamed** from `bigjoestretch` to `joelcottrell`. Every URL
>    in this document uses the old username and is therefore stale. Old URLs currently
>    redirect, but only while the `bigjoestretch` namespace holds no repository of the same
>    name.
> 2. **The script header in section 7.3 is out of date.** Do not copy it from here. The
>    authoritative version lives in
>    [`_Template/Tier1-Standard/Verb-Noun.ps1`](../_Template/Tier1-Standard/Verb-Noun.ps1),
>    with guidance in [PROJECT-TEMPLATE.md](./PROJECT-TEMPLATE.md).
>
> For the rules that are actually in force, see
> [NAMING-CONVENTIONS.md](./NAMING-CONVENTIONS.md) and
> [PROJECT-TEMPLATE.md](./PROJECT-TEMPLATE.md).
>
> Where execution deviated from this plan, the deviations and their reasons are recorded in
> the commit messages on the `refactor/repository-structure` branch.

---

## 0. How to use this document

This plan is written to be handed to a **Claude Cowork** or **Claude Code** session running
on a machine with `git` and `gh` installed and authenticated. Work through the phases in
order. Do not skip Phase 1, and do not push directly to `main` at any point.

**Prerequisites on the executing machine:**

- Git for Windows installed and on PATH (`git --version`)
- GitHub CLI installed and authenticated (`gh auth status`)
- A clone location in a plain local folder, NOT inside OneDrive
  (recommended: `C:\Repos\powershell-toolkit`)
- Working tree clean before starting

**Why not OneDrive for this task:** git repositories inside OneDrive can produce sync
conflicts on `.git` internals, and this reorg touches nearly every path in the tree.
Clone fresh to a local folder, complete the reorg, push. Other machines clone the
finished result from GitHub, which is what git is for.

---

## 1. Objectives

1. Reduce 13 loosely related top-level folders to 8 coherent parent domains.
2. Establish a two-tier project template so every new script folder starts from a skeleton.
3. Eliminate spaces from all paths so raw GitHub URLs work without percent-encoding.
4. Standardize casing (`VMware`, not `VMWare`; `README.md`, not `README.MD`).
5. Add repository-level `.gitignore` and `.gitattributes`.
6. Rewrite READMEs at three levels: root index, category, and project.
7. Preserve file history using `git mv` throughout.
8. Deliver the whole change as a single reviewable pull request.

---

## 2. Target structure

```
powershell-toolkit/
├── .gitattributes
├── .gitignore
├── LICENSE
├── README.md                          # Root index
├── _Template/
│   ├── README.md                      # How to use these skeletons
│   ├── Tier1-Standard/
│   └── Tier2-Full/
├── docs/
│   ├── REORG-PLAN.md                  # This document
│   ├── NAMING-CONVENTIONS.md
│   └── PROJECT-TEMPLATE.md
├── Azure/
│   ├── README.md
│   └── Automation/
│       └── README.md
├── Endpoint/
│   ├── README.md
│   └── Intune/
│       └── README.md
├── Identity/
│   ├── README.md
│   ├── ActiveDirectory/
│   │   └── README.md
│   ├── EntraID/
│   │   └── README.md
│   └── MicrosoftGraph/
│       └── README.md
├── Microsoft365/
│   ├── README.md
│   ├── Exchange/
│   │   └── README.md
│   ├── SharePoint/
│   │   └── README.md
│   ├── Teams/
│   │   └── README.md
│   └── Tenant/
│       └── README.md
├── Shared/
│   └── README.md
├── Virtualization/
│   ├── README.md
│   └── VMware/
│       ├── README.md
│       └── PowerCLI/
│           ├── README.md
│           ├── Hosts/
│           ├── Networking/
│           ├── Reporting/
│           └── VirtualMachines/
└── Windows/
    ├── README.md
    ├── Client/
    │   └── README.md
    ├── Common/
    │   └── README.md
    └── Server/
        └── README.md
```

**Design notes:**

- `Endpoint/` currently holds only `Intune/`. This is intentional. Intune is a management
  plane covering Windows, iOS, Android, and macOS, so it does not belong under `Windows/`.
  The parent leaves room for Autopilot, Defender for Endpoint, and ConfigMgr.
- `Windows/Common/` holds scripts that run on both server and workstation (registry,
  networking traces, event logs, certificates). Without it, every OS-agnostic script
  becomes an arbitrary judgment call.
- `Identity/MicrosoftGraph/` is retained as a first-class folder per decision. Scripts that
  use Graph purely as a transport to manage a specific workload should still be filed under
  that workload (a Graph script that manages mailboxes goes in `Microsoft365/Exchange/`).
  `Identity/MicrosoftGraph/` is for Graph-centric tooling: authentication helpers, app
  registration management, permission auditing, generic Graph query wrappers.

---

## 3. Naming conventions

These are non-negotiable and should be recorded in `docs/NAMING-CONVENTIONS.md`.

| Element | Rule | Example |
|---------|------|---------|
| Folder names | PascalCase, no spaces, no underscores | `ActiveDirectory`, `PortGroup-Provisioning` |
| Multi-word projects | PascalCase segments joined by a single hyphen | `PortGroup-Provisioning` |
| Script files | PowerShell approved `Verb-Noun.ps1` | `New-DistributedPortGroups.ps1` |
| README files | Always exactly `README.md` | not `README.MD`, not `Readme.md` |
| Changelog files | Always exactly `CHANGELOG.md` | |
| Vendor casing | Match the vendor | `VMware`, `PowerCLI`, `Microsoft365`, `EntraID` |
| Reserved prefix | `_` prefixes sort-first meta folders only | `_Template` |
| Config samples | `<name>.example.csv`, never a live `<name>.csv` | `portgroups.example.csv` |

**The spaces rule matters more than it looks.** Every script in this repository carries a
remote-execution header built on `raw.githubusercontent.com`. A folder named
`Azure Runbook` becomes `Azure%20Runbook` in that URL. Percent-encoded paths work but they
break copy-paste, they break shell quoting in scheduled tasks, and they are a recurring
source of silent failure. No spaces, anywhere, ever.

---

## 4. Migration mapping

### 4.1 Direct moves (no inventory required)

| Current path | Target path |
|--------------|-------------|
| `ActiveDirectory/` | `Identity/ActiveDirectory/` |
| `AzureAD/` | `Identity/EntraID/` |
| `MsGraph/` | `Identity/MicrosoftGraph/` |
| `Exchange/` | `Microsoft365/Exchange/` |
| `SharePoint/` | `Microsoft365/SharePoint/` |
| `Teams/` | `Microsoft365/Teams/` |
| `Azure Runbook/` | `Azure/Automation/` |
| `Intune/` | `Endpoint/Intune/` |
| `VMWare/PowerCLI/` | `Virtualization/VMware/PowerCLI/` |
| `VMWare/PowerCLI/Networking/PortGroup-Provisioning/` | `Virtualization/VMware/PowerCLI/Networking/PortGroup-Provisioning/` |
| `LICENSE` | unchanged |

### 4.2 Moves requiring inventory first

These four folders must be listed and their contents classified before moving. Run the
inventory step in Phase 2 and report findings before executing the moves.

| Current path | Disposition |
|--------------|-------------|
| `Office365/` | **Dissolve.** Classify each item into `Microsoft365/Exchange`, `SharePoint`, `Teams`, or `Tenant`. Anything that is genuinely tenant-wide (licensing, service health, tenant config, cross-workload reporting) goes to `Microsoft365/Tenant/`. The folder itself is removed. |
| `PowerShell/` | **Dissolve.** Reusable functions, modules, and snippets go to `Shared/`. OS-level scripts (registry, netsh, event log, services) go to `Windows/Common/`. Anything workload-specific goes to its workload folder. |
| `Windows/` | **Split.** Classify each item into `Windows/Server/`, `Windows/Client/`, or `Windows/Common/`. When a script runs unmodified on both, it goes to `Common/`. |
| `VMWare/PowerCLI/Connect to External Identity Pro.../` | **Rename and file.** Space-bearing name must go. Target: `Virtualization/VMware/PowerCLI/Hosts/Connect-ExternalIdentityProvider/` (confirm the exact current folder name during inventory). |

### 4.3 Casing fixes

| Current | Target | Note |
|---------|--------|------|
| `VMWare/` | `VMware/` | Resolved implicitly by the move into `Virtualization/VMware/`. |
| `VMWare/PowerCLI/README.MD` | `.../PowerCLI/README.md` | Case-only rename. See warning below. |

**Case-only rename warning (Windows):** NTFS is case-insensitive, so `git mv README.MD README.md`
will fail or silently no-op. Use the two-step form:

```powershell
git mv README.MD README.tmp
git mv README.tmp README.md
```

Or force it in a single step:

```powershell
git mv -f README.MD README.md
```

Verify afterward with `git ls-files | Select-String -CaseSensitive 'README'`.

---

## 5. Execution phases

### Phase 1: Safety net

```powershell
# Clone fresh to a local (non-OneDrive) folder
cd C:\Repos
git clone https://github.com/bigjoestretch/powershell-toolkit.git
cd powershell-toolkit

# Confirm clean state
git status
git log --oneline -5

# Tag the pre-reorg state so existing raw URLs remain reachable forever
git tag -a v1.0-pre-reorg -m "Repository state prior to structural reorganization"
git push origin v1.0-pre-reorg

# Create the working branch
git checkout -b refactor/repository-structure
```

**Why the tag matters:** every raw URL currently in use points at `main`. After the reorg
those paths return 404. Any scheduled task, bookmark, or documented one-liner built on the
old layout can be repointed at the tag instead of `main`:

```
https://raw.githubusercontent.com/bigjoestretch/powershell-toolkit/v1.0-pre-reorg/<old/path>.ps1
```

This is a migration bridge, not a permanent answer. Update the consumers to the new paths.

### Phase 2: Inventory

Before moving anything, produce a complete listing and report it back for classification
decisions:

```powershell
git ls-files | Sort-Object
```

Specifically enumerate and classify the contents of `Office365/`, `PowerShell/`, `Windows/`,
and the space-bearing folder under `VMWare/PowerCLI/`. **Stop here and report.** Do not
guess at classifications.

### Phase 3: Scaffold

Create the new parent directories with `.gitkeep` placeholders so the moves have targets:

```powershell
$dirs = @(
    'Azure/Automation',
    'Endpoint/Intune',
    'Identity/ActiveDirectory',
    'Identity/EntraID',
    'Identity/MicrosoftGraph',
    'Microsoft365/Exchange',
    'Microsoft365/SharePoint',
    'Microsoft365/Teams',
    'Microsoft365/Tenant',
    'Shared',
    'Virtualization/VMware/PowerCLI/Hosts',
    'Virtualization/VMware/PowerCLI/Networking',
    'Virtualization/VMware/PowerCLI/Reporting',
    'Virtualization/VMware/PowerCLI/VirtualMachines',
    'Windows/Client',
    'Windows/Common',
    'Windows/Server',
    '_Template/Tier1-Standard',
    '_Template/Tier2-Full',
    'docs'
)
foreach ($d in $dirs) {
    New-Item -Path $d -ItemType Directory -Force | Out-Null
    New-Item -Path "$d/.gitkeep" -ItemType File -Force | Out-Null
}
git add .
git commit -m "Scaffold new repository structure"
```

Remove each `.gitkeep` in Phase 4 as real content lands in that folder.

### Phase 4: Move content

Execute the direct moves from section 4.1, then the inventory-driven moves from 4.2.
Use `git mv` exclusively. Never delete-and-re-add, which severs file history.

Commit in logical groups so the pull request diff is reviewable:

```powershell
# Group 1: Identity
git mv ActiveDirectory/* Identity/ActiveDirectory/
git mv AzureAD/* Identity/EntraID/
git mv MsGraph/* Identity/MicrosoftGraph/
git commit -m "Consolidate identity platforms under Identity/"

# Group 2: Microsoft 365
git mv Exchange/* Microsoft365/Exchange/
git mv SharePoint/* Microsoft365/SharePoint/
git mv Teams/* Microsoft365/Teams/
git commit -m "Consolidate Microsoft 365 workloads under Microsoft365/"

# Group 3: Office365 dissolution (paths determined by Phase 2 inventory)
git commit -m "Dissolve Office365/ into Microsoft365 workload folders"

# Group 4: Azure and Endpoint
git mv "Azure Runbook"/* Azure/Automation/
git mv Intune/* Endpoint/Intune/
git commit -m "Relocate Azure Automation and Intune, remove spaces from paths"

# Group 5: Virtualization
git mv VMWare/PowerCLI/* Virtualization/VMware/PowerCLI/
git commit -m "Relocate VMware PowerCLI, correct vendor casing"

# Group 6: Windows split (paths determined by Phase 2 inventory)
git commit -m "Split Windows/ into Server, Client, and Common"

# Group 7: PowerShell dissolution (paths determined by Phase 2 inventory)
git commit -m "Dissolve PowerShell/ into Shared and Windows/Common"
```

After each group, remove the now-empty source folder and its `.gitkeep` placeholders.
Verify with `git status` that nothing shows as deleted-and-added rather than renamed.

### Phase 5: Repository-level files

Create `.gitignore` and `.gitattributes` (contents in section 6), the `_Template` skeletons
(section 7), and `docs/` (this plan plus the conventions documents).

```powershell
git add .gitignore .gitattributes _Template docs
git commit -m "Add repository .gitignore, .gitattributes, project templates, and docs"
```

### Phase 6: Documentation

Write READMEs at all three levels using the templates in section 8. Rewrite the root
README as an index. Commit separately:

```powershell
git add .
git commit -m "Rewrite READMEs at root, category, and project levels"
```

### Phase 7: Verification

Run the checklist in section 10. Fix anything that fails before opening the pull request.

### Phase 8: Pull request

```powershell
git push -u origin refactor/repository-structure

gh pr create `
    --title "Restructure repository into domain-based hierarchy" `
    --body-file docs/PR-BODY.md
```

Review the diff on GitHub. Confirm renames are shown as renames, not as mass
deletions plus additions. Merge when satisfied.

---

## 6. Repository-level file contents

### 6.1 `.gitignore`

```gitignore
# Logs
Logs/
*.log

# Timestamped script output
*_[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]_[0-9][0-9][0-9][0-9][0-9][0-9].csv
Output/
Reports/

# Live configuration (examples are tracked, working copies are not)
Config/*.csv
!Config/*.example.csv
Config/*.json
!Config/*.example.json

# Credentials and secrets - never commit
*.cred
*.key
*.pfx
*.cer
credentials.xml
secrets.*

# Editor and OS artifacts
.vs/
.vscode/
*.suo
*.user
Thumbs.db
desktop.ini
$RECYCLE.BIN/

# PowerShell module output
*.nupkg
```

The credentials block is the important one. A single committed `.cred` file in a public
repository is a security incident, and a hospital environment makes that worse.

### 6.2 `.gitattributes`

```gitattributes
* text=auto

*.ps1   text eol=crlf
*.psm1  text eol=crlf
*.psd1  text eol=crlf
*.bat   text eol=crlf
*.cmd   text eol=crlf

*.md    text eol=lf
*.yml   text eol=lf
*.yaml  text eol=lf
*.json  text eol=lf
*.csv   text eol=crlf

*.png   binary
*.jpg   binary
*.pfx   binary
*.cer   binary
*.der   binary
```

PowerShell files are pinned to CRLF because Windows PowerShell 5.1 handles them most
predictably, and this prevents a whole-file diff every time the repository is touched from
a different machine.

---

## 7. Project templates

### 7.1 Tier 1 (Standard)

Use when the project is a single self-contained script with no external configuration
and no log output.

```
Project-Name/
├── Verb-Noun.ps1
├── README.md
├── CHANGELOG.md
└── .gitignore
```

### 7.2 Tier 2 (Full)

Use when the project reads external configuration, ships more than one script, or writes
logs. This mirrors the existing `PortGroup-Provisioning` layout.

```
Project-Name/
├── Verb-Noun.ps1
├── Config/
│   └── settings.example.csv
├── Docs/
│   ├── Operational-Notes.md
│   └── Reference.md
├── Examples/
│   └── Usage-Examples.ps1
├── Tests/
│   └── Project.Tests.ps1
├── Logs/
│   └── .gitkeep
├── CHANGELOG.md
├── README.md
└── .gitignore
```

**Tier selection rule:** if a folder in the Tier 2 skeleton would ship empty, you have
picked the wrong tier. Empty `Tests/` and `Config/` folders read as abandonment. Start at
Tier 1 and promote when the project earns it.

### 7.3 Mandatory script header

Every `.ps1` in this repository carries this header. **ASCII characters only, no Unicode.**

```powershell
<#
.SYNOPSIS
    One-line description of what the script does.

.DESCRIPTION
    Fuller explanation covering what problem it solves, what it changes, and what
    it deliberately does not do.

.PARAMETER ParameterName
    Description of each parameter.

.EXAMPLE
    .\Verb-Noun.ps1 -ParameterName "value"
    Describes what this invocation does.

.NOTES
    File Name  : Verb-Noun.ps1
    Author     : Joel Cottrell
    Version    : 1.0.0
    Updated    : YYYY-MM-DD
    Requires   : PowerShell 5.1 or later, <module names>

    Repository : https://github.com/bigjoestretch/powershell-toolkit

    ==========================================================================
    REMOTE EXECUTION FROM GITHUB
    ==========================================================================

    Option 1 - Run directly without downloading:

        $u = "https://raw.githubusercontent.com/bigjoestretch/powershell-toolkit/main/<Domain>/<Technology>/<Project>/Verb-Noun.ps1"
        Invoke-Expression (Invoke-WebRequest -Uri $u -UseBasicParsing).Content

    Option 2 - Download and run (recommended, allows review before execution):

        $u = "https://raw.githubusercontent.com/bigjoestretch/powershell-toolkit/main/<Domain>/<Technology>/<Project>/Verb-Noun.ps1"
        $p = "C:\Scripts\Verb-Noun.ps1"
        New-Item -Path (Split-Path $p) -ItemType Directory -Force | Out-Null
        Invoke-WebRequest -Uri $u -OutFile $p -UseBasicParsing
        & $p

    Option 3 - Scheduled task (refreshes the script on each run):

        $u = "https://raw.githubusercontent.com/bigjoestretch/powershell-toolkit/main/<Domain>/<Technology>/<Project>/Verb-Noun.ps1"
        $p = "C:\Scripts\Verb-Noun.ps1"
        $cmd = "Invoke-WebRequest -Uri '$u' -OutFile '$p' -UseBasicParsing; & '$p'"
        $act = New-ScheduledTaskAction -Execute "powershell.exe" `
                   -Argument "-NoProfile -ExecutionPolicy Bypass -Command `"$cmd`""
        $trg = New-ScheduledTaskTrigger -Daily -At 3am
        Register-ScheduledTask -TaskName "Verb-Noun" -Action $act -Trigger $trg `
                   -RunLevel Highest -User "SYSTEM"

    ==========================================================================
#>
```

**Security note to include in the category README:** Option 1 executes remote code without
review. It is convenient for a public repository you control, but it is exactly the pattern
security teams flag. Option 2 is the default recommendation. Option 3 re-downloads on every
run, so a compromised repository would propagate immediately. For anything touching
production, pin to a release tag rather than `main`.

---

## 8. README templates

### 8.1 Root README (index)

Replaces hand-maintained example commands, which drift. Structure:

1. Badge row: PowerShell, License, Last Commit, Issues
2. Title and two-paragraph positioning statement (keep the existing voice: battle-tested,
   healthcare enterprise, 20 years)
3. **Repository index table**: Domain | Technologies | Description | Link
4. Repository structure tree (fenced code block)
5. Getting Started: prerequisites, module install matrix, clone instructions
6. Conventions: link to `docs/NAMING-CONVENTIONS.md` and `docs/PROJECT-TEMPLATE.md`
7. Remote execution: brief explanation plus the security caveat, link to a project README
   for the full pattern
8. Best Practices, Contributing, License, About the Author, Disclaimer, Support
9. Technology badge row footer

### 8.2 Category README (parent and child folders)

Every folder from `Identity/` down to `Identity/ActiveDirectory/` gets one. Structure:

1. Title: `<Domain>` or `<Domain> - <Technology>`
2. One-paragraph scope statement: what belongs here and what does not
3. **Project table**: Project | Description | Tier
4. Shared prerequisites: modules and permissions common to everything in the folder
5. Related folders: cross-links where scripts commonly pair up
6. Back-link to the repository root

Keep these short. Their job is navigation, not documentation.

### 8.3 Project README

Model directly on the existing `PortGroup-Provisioning` README, which is the strongest
document in the repository. Structure:

1. Title: `<Technology> - <Project Name>`
2. Opening paragraph plus emoji-prefixed capability bullets
3. Per-script section: script link, purpose, Requirements, Configuration, Usage,
   Existing Object Behavior
4. Project Structure (fenced tree)
5. Configuration Review and Confirmation (where interactive confirmation applies)
6. Console Progress
7. Logging
8. Safety Features
9. Important Scope Notes (what the script deliberately does not do)
10. Testing
11. Remote Execution (the three options from section 7.3)
12. Additional Documentation (links into `Docs/`)
13. Author
14. License
15. Blockquote footer: always test in non-production first

Sections 9 and 11 are the two most valuable and the two most often skipped. Scope Notes
prevent someone assuming the script does more than it does. Remote Execution is the reason
the header convention exists.

---

## 9. Pull request body

Save as `docs/PR-BODY.md`:

```markdown
## Summary

Restructures the repository from 13 loosely related top-level folders into 8 domain-based
parents with technology children. No script logic is modified.

## Changes

- Consolidated identity platforms under `Identity/` (ActiveDirectory, EntraID, MicrosoftGraph)
- Consolidated M365 workloads under `Microsoft365/`; dissolved `Office365/`
- Relocated `Azure Runbook/` to `Azure/Automation/`, removing the space from the path
- Relocated `Intune/` to `Endpoint/Intune/`
- Relocated VMware content to `Virtualization/VMware/PowerCLI/`, correcting vendor casing
- Split `Windows/` into `Server/`, `Client/`, and `Common/`
- Dissolved the generic `PowerShell/` folder into `Shared/` and `Windows/Common/`
- Added repository `.gitignore` and `.gitattributes`
- Added `_Template/` with Tier 1 and Tier 2 project skeletons
- Rewrote READMEs at root, category, and project levels
- Added `docs/` with the reorg plan, naming conventions, and template guide

## Breaking changes

All raw GitHub URLs pointing at the previous layout will return 404 after merge. The
pre-reorg state is preserved at tag `v1.0-pre-reorg` as a migration bridge. Consumers
should be updated to the new paths.

## Verification

- [ ] All moves recorded as renames, not delete-plus-add
- [ ] No spaces in any tracked path
- [ ] No file named `README.MD`
- [ ] All raw URLs in script headers resolve
- [ ] No credential files tracked
```

---

## 10. Verification checklist

Run before opening the pull request.

```powershell
# 1. No spaces in any tracked path
git ls-files | Where-Object { $_ -match ' ' }
# Expected: no output

# 2. No incorrect README casing
git ls-files | Where-Object { $_ -cmatch 'README\.MD$' }
# Expected: no output

# 3. No lingering VMWare casing
git ls-files | Where-Object { $_ -cmatch 'VMWare' }
# Expected: no output

# 4. Moves recorded as renames
git diff --stat -M --summary main...HEAD | Select-String 'rename'
# Expected: rename entries, not large delete/create pairs

# 5. Every project folder has a README and CHANGELOG
Get-ChildItem -Recurse -Filter *.ps1 |
    Select-Object -ExpandProperty DirectoryName -Unique |
    ForEach-Object {
        if (-not (Test-Path "$_\README.md"))    { "Missing README:    $_" }
        if (-not (Test-Path "$_\CHANGELOG.md")) { "Missing CHANGELOG: $_" }
    }

# 6. No credential material tracked
git ls-files | Where-Object { $_ -match '\.(cred|key|pfx|cer)$' }
# Expected: no output

# 7. No empty scaffold placeholders left where real content landed
git ls-files | Where-Object { $_ -match '\.gitkeep$' }
# Expected: only Logs/.gitkeep entries and genuinely empty future folders

# 8. Every raw URL in every script header resolves
Get-ChildItem -Recurse -Filter *.ps1 | ForEach-Object {
    Select-String -Path $_.FullName -Pattern 'raw\.githubusercontent\.com\S+\.ps1' -AllMatches |
        ForEach-Object { $_.Matches.Value }
} | Sort-Object -Unique | ForEach-Object {
    $code = try { (Invoke-WebRequest -Uri $_ -Method Head -UseBasicParsing).StatusCode }
            catch { $_.Exception.Response.StatusCode.value__ }
    [PSCustomObject]@{ Url = $_; Status = $code }
} | Where-Object { $_.Status -ne 200 }
# Expected: no output
```

Check 8 is the one that catches the most real problems. Run it after the branch is pushed
but before merge, and note that raw URLs pointing at `main` will not resolve until merge.
Run it a second time after merging.

---

## 11. Rollback

Nothing here is destructive if the phases are followed. Recovery options in order of
preference:

1. **Before merge:** delete the branch. `main` is untouched.
   ```powershell
   git checkout main
   git branch -D refactor/repository-structure
   git push origin --delete refactor/repository-structure
   ```

2. **After merge, targeted fix:** correct the specific paths on a new branch.

3. **After merge, full revert:** revert the merge commit.
   ```powershell
   git revert -m 1 <merge-commit-sha>
   ```

4. **Worst case:** the `v1.0-pre-reorg` tag holds the complete pre-reorg tree and can be
   checked out or cherry-picked from at any time.

---

## 12. Post-merge follow-up

Not part of this pull request, but queue them:

- Repoint any existing scheduled tasks or documented one-liners to the new paths
- Migrate scripts from the local `Development\Scripts` tree into the new structure,
  one project at a time, each with a README and CHANGELOG
- Consider a PSScriptAnalyzer GitHub Action to lint every push
- Consider branch protection on `main` requiring a pull request
- Consider tagging releases (`v1.1`, `v1.2`) so production consumers can pin to a tag
  rather than tracking `main`

---

**Prepared for handoff to a Claude Cowork or Claude Code session.**
Execute phases in order. Stop and report after Phase 2 before making classification
decisions on `Office365/`, `PowerShell/`, `Windows/`, and the space-bearing VMware folder.
