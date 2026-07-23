## Summary

Restructures the repository from 13 loosely related top-level folders into
domain-based parents with technology children. No script logic is modified,
apart from three pre-existing defects fixed in passing and one hardcoded
credential removed.

## Changes

### Structure

- Consolidated identity platforms under `Identity/` (ActiveDirectory, EntraID, MicrosoftGraph)
- Consolidated M365 workloads under `Microsoft365/`; dissolved `Office365/`
- Relocated `Azure Runbook/` to `Azure/Automation/`, removing the space from the path
- Relocated `Intune/` to `Endpoint/Intune/`
- Relocated VMware content to `Virtualization/VMware/PowerCLI/`, correcting vendor casing
- Added `Virtualization/VMware/PowerCLI/Authentication/` for the external identity
  provider content, which is vCenter authentication rather than ESXi host management
- Split `Windows/` into `Server/`, `Client/`, and `Common/`
- Dissolved the generic `PowerShell/` folder into `Shared/`

### Naming

- **Removed all 55 space-bearing paths.** 49 were under `Intune/`
- Renamed 22 scripts to approved `Verb-Noun` form, removing underscores and
  lowercase filenames
- Fixed three `README.MD` to `README.md`
- Normalised `.JSON` to `.json` on custom compliance definitions

### Repository files

- Added `.gitignore` and `.gitattributes`
- Added `_Template/` with Tier 1 and Tier 2 project skeletons
- Added `docs/` with the reorg plan, naming conventions, and template guide

### Security and correctness

- **Removed a hardcoded Datto RMM SiteID and platform name.** The SiteID is the
  only token required to download an agent installer bound to a specific tenant
  site. It is now a mandatory, GUID-validated parameter with no default
- **Reworked the profile bootstrap.** It previously downloaded and dot-sourced a
  profile from a raw GitHub URL on every shell start, unpinned and unverified.
  It now loads a local cache with no network access at startup, and updates only
  on explicit request with SHA256 verification
- Removed a corporate support address, a partner ServiceNow URL, a support phone
  number, and OEM registry branding values
- Repointed every repository URL from the retired `bigjoestretch/public` to
  `joelcottrell/powershell-toolkit`, and removed all percent-encoded paths
- Converted all script content to ASCII per the naming conventions

### Pre-existing defects fixed

- The profile used PowerShell 7's null-coalescing operator, a parse error under
  Windows PowerShell 5.1
- `New-StandardSwitchPortGroups.ps1` interpolated a variable directly before a
  colon in two `Write-Progress` strings, which PowerShell parses as a scope
  qualifier
- The compliance README rendered the same screenshot twice

All 31 scripts now parse cleanly under Windows PowerShell 5.1. Two did not before.

## Breaking changes

All raw GitHub URLs pointing at the previous layout will return 404 after merge.
The pre-reorg state is preserved at tag `v1.0-pre-reorg` as a migration bridge:

```
https://raw.githubusercontent.com/joelcottrell/powershell-toolkit/v1.0-pre-reorg/<old/path>.ps1
```

That is a bridge, not a destination. Update consumers to the new paths.

Separately, the GitHub account was renamed from `bigjoestretch` to
`joelcottrell`. Old URLs currently redirect, but that redirect survives only
while the `bigjoestretch` namespace holds no repository of the same name. It is
held as an organisation specifically to prevent a third party claiming it.

## Verification

- [x] All moves recorded as renames, not delete-plus-add
- [x] No spaces in any tracked path
- [x] No file named `README.MD`
- [x] No lingering `VMWare` casing
- [x] No credential files tracked
- [x] No former-employer identifiers in any tracked file
- [x] All 31 scripts parse under Windows PowerShell 5.1
- [x] No non-ASCII characters in any script
- [ ] All raw URLs in script headers resolve (run after merge - they point at `main`)
