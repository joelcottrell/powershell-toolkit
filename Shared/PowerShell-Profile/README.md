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
