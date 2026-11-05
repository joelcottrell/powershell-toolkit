# Shared - PowerShell Profile

![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-blue?logo=powershell&logoColor=white)
![Scope](https://img.shields.io/badge/Scope-Shared-lightgrey)

A centrally managed PowerShell profile, plus a bootstrap loader that keeps it in
sync across machines without executing remote code on every shell start.

---

## Scripts

| Script | Purpose |
| --- | --- |
| [Import-RemoteProfile.ps1](./Import-RemoteProfile.ps1) | Bootstrap. Loads the cached profile, and updates it on request. |
| [Microsoft.PowerShell_profile.ps1](./Microsoft.PowerShell_profile.ps1) | The profile itself: module loading, prompt, session banner. |

> `Microsoft.PowerShell_profile.ps1` keeps its underscore because PowerShell
> requires that exact filename. It is the one file in this repository exempt
> from the `Verb-Noun` rule.

---

## Security model

**Read this before using the bootstrap.**

Version 1 of the loader downloaded the profile from a GitHub raw URL and
dot-sourced it every time a shell opened. That is convenient and it is also the
pattern security teams flag, for good reason:

- Every new session ran whatever that URL returned, unreviewed.
- It tracked `main`, so a force-push changed what ran everywhere.
- Nothing verified integrity, so any tampering en route or at rest was invisible.
- A GitHub account rename releases the old username. If someone claimed it and
  recreated the path, they would have code execution in every shell on every
  machine running the profile.

Version 2 changes the trust boundary. You trust the code **at the moment you run
`Update-PowerShellProfile`**, not on every shell start:

| Behaviour | v1 | v2 |
| --- | --- | --- |
| Network access at shell start | Every session | None |
| Source | `main`, always | Any tag or commit SHA you pin |
| Integrity check | None | SHA256, shown and optionally enforced |
| Update timing | Silent, automatic | Explicit, with confirmation |
| Staging path | Predictable name in shared temp | Random name in your own profile directory, moved atomically |

The profile still lives in one place and still reaches all your machines. You
just decide when new code arrives.

---

## Setup

**1. Install the bootstrap into your profile.**

```powershell
if (-not (Test-Path $PROFILE)) { New-Item -Path $PROFILE -ItemType File -Force }
notepad $PROFILE
```

Paste the contents of `Import-RemoteProfile.ps1` into that file and save.

**2. Fetch the profile.**

```powershell
Update-PowerShellProfile
```

It prints the SHA256 of what it downloaded and asks before installing. Review
the source first; the URL is printed for you.

**3. Reload.**

```powershell
. $PROFILE
```

---

## Updating

```powershell
Update-PowerShellProfile
```

No-ops if you already have the current version. Otherwise it shows the SHA256 of
both the current and incoming copies and asks before replacing.

### Pinning

Editing a branch changes what everyone gets. Pin to a tag instead:

```powershell
$ProfileRef = 'v1.1'
```

To refuse anything but a specific reviewed version, set the expected hash:

```powershell
$ProfileExpectedSha256 = '<sha256 from a previous run>'
```

With both set, an update installs only when the content matches exactly:

```powershell
Update-PowerShellProfile -Ref 'v1.1' -ExpectedSha256 '<hash>' -Force
```

That combination is the right one for anything you care about, and it is what a
scheduled or unattended update should always use.

---

## Reference

| Command | Purpose |
| --- | --- |
| `Update-PowerShellProfile` | Fetch, verify, and install the profile. |
| `Get-PowerShellProfileHash` | SHA256 of the currently cached profile. |

| Variable | Default | Purpose |
| --- | --- | --- |
| `$ProfileRef` | `main` | Branch, tag, or commit SHA to fetch. |
| `$ProfileExpectedSha256` | empty | Pinned hash. Empty means prompt instead of enforce. |
| `$ProfileCachePath` | `<profile dir>\RemoteProfile\` | Where the cached profile lives. |

| Environment variable | Effect |
| --- | --- |
| `PS_SKIP_PROFILE` | Set to any value to skip loading entirely. Useful for debugging a broken profile. |

If the cached profile throws, the session still starts and a warning is printed.
You get a bare shell rather than a broken one.

---

## Troubleshooting

**"No cached profile found"** - expected on a new machine. Run `Update-PowerShellProfile`.

**A bad profile is breaking my shell.** Start with `$env:PS_SKIP_PROFILE=1`, or
delete the cached file and re-run the update.

**Update fails on TLS.** Windows PowerShell 5.1 may negotiate TLS 1.0, which
GitHub rejects. The script raises this to TLS 1.2 automatically; if it still
fails, your machine is likely blocking `raw.githubusercontent.com`.

---

## Author

**Joel Cottrell** - [github.com/joelcottrell](https://github.com/joelcottrell)

---

[Back to repository root](../../README.md)


## Interactive profile selector (v2.1.0)

Startup defaults to a lightweight local profile. At an interactive PowerShell ConsoleHost prompt:

- **Y** or **Enter**: lightweight local profile, no VCF.PowerCLI import.
- **N**: load the previously reviewed cached GitHub-managed profile, including installed VCF.PowerCLI.
- **Load-FullProfile**: activate the cached full profile later in the same session.
- **Show-ProfileHealth**: inspect current session profile state.
- **Update-PowerShellProfile**: explicitly download, syntax-check, hash, and confirm a cache replacement. Use `-Ref <commit-sha> -ExpectedSha256 <hash>` for pinning. Do not blindly approve code changes.

### Installation

1. Download or clone this folder to a local working directory, then review the scripts.
2. Open PowerShell 7 and run `.\\Install-PowerShellProfile.ps1 -WhatIf` from that folder to preview the installation.
3. Run `.\\Install-PowerShellProfile.ps1` and confirm the action. The installer backs up the current `$PROFILE` with a timestamp before replacing it.
4. Restart PowerShell. Choose **Y** to test local startup.
5. After reviewing the remote full profile, run `Update-PowerShellProfile` to create the local cache. Restart and choose **N**, or run `Load-FullProfile`.

**Important:** The installer is designed for the current `$PROFILE` path, which varies between PowerShell 7 and Windows PowerShell 5.1. Do not run the installer directly from a remote URL. A full profile cache is not bundled with the installer. A first-time **N** selection falls back to local until a cache is explicitly installed.

### Automation

Use `pwsh -NoProfile` for scripts that must not load a user profile. For hosts that do load profiles, set `PS_PROFILE_MODE=local` to bypass the prompt. `PS_PROFILE_MODE=full` explicitly loads the cached full profile. `PS_SKIP_PROFILE=1` skips full-profile loading. Noninteractive and redirected-input ConsoleHost sessions default to local.

### Performance and security

Full profile startup no longer runs `Find-Module` or `Update-Module`, and it does not change persistent PowerCLI certificate verification settings. Module installation and upgrades should be performed explicitly. The full profile is still responsible for importing an already installed VCF.PowerCLI module, so full mode can take longer than local mode. The cache is syntax-checked at load time, but syntax checking is **not** an authenticity guarantee: review and pin remote updates before trusting them.

### Install directly from GitHub without a repository checkout

After the feature is merged and reviewed, use PowerShell 7 to download only the installer to a temporary location:

```powershell
$installer = Join-Path $env:TEMP 'Install-FromGitHub.ps1'
Invoke-WebRequest 'https://raw.githubusercontent.com/joelcottrell/powershell-toolkit/main/Shared/PowerShell-Profile/Install-FromGitHub.ps1' -OutFile $installer
notepad $installer  # Review before executing
& $installer -Ref main -WhatIf
& $installer -Ref main
```

The installer downloads the two necessary profile files from GitHub, validates PowerShell syntax, prints SHA256 hashes, and asks for confirmation before backing up and replacing the local profile files. Prefer passing `-BootstrapSha256` and `-LocalSha256` from a trusted reviewed release, and pin `-Ref` to a commit SHA for stronger reproducibility. This is **not** an unattended or automatic update mechanism. The installer does not download or execute the full VCF profile; use `Update-PowerShellProfile` separately to review and cache it.

Do not delete the existing extracted feature-branch directory until installation and both startup modes have been verified.

## Infrastructure module selection and automatic updates (v2.2.0)

Choose **N** at the initial startup prompt to load the cached full GitHub profile. Then choose **1** for VMware VCF.PowerCLI, **2** for the modern Nutanix v4 SDK modules `Nutanix.Prism` and `Nutanix.Vmm`, **3** for both, or **4/Enter** for none. Only selected modules are checked or imported. `Load-VCF` and `Load-Nutanix` work on demand.

A successful PSGallery check is recorded per module in `$env:LOCALAPPDATA\PowerShellProfile\module-state.json`. A new check runs after 24 hours; newer stable releases install automatically side by side. Missing modules prompt before installation. Failures do not advance the timestamp. No automatic Authenticode publisher-check bypass or persistent PowerCLI configuration changes occur. An update to an already loaded module may require restarting PowerShell to activate the new assembly version. Nutanix v4 modules are published separately, and this profile starts with Prism and VMM; additional SDK modules can be added as needed.

To activate the new functionality on an already installed Profile Manager, run `Update-PowerShellProfile` and then start a fresh PowerShell session, choose **N**, and select the module set. Local startup stays fast.
