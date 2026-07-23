# Changelog

All notable changes to the PowerShell Profile project are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [2.0.0]

### Changed

- **Breaking.** The bootstrap no longer downloads and executes the profile on
  every shell start. It loads a locally cached copy and performs no network
  access at session start. Remote code now arrives only when
  `Update-PowerShellProfile` is run deliberately.
- Updates can be pinned to a tag or commit SHA rather than tracking `main`, so a
  force-push cannot silently change what runs.
- Downloads are staged to a random filename inside the user's own profile
  directory and moved into place atomically, replacing the previous predictable
  path in the shared temp directory.
- Renamed from `dynamic_powershell_profile_loader.ps1` to
  `Import-RemoteProfile.ps1` per the repository naming conventions.

### Added

- `Update-PowerShellProfile` - fetches, hashes, and installs the profile, with
  confirmation before replacing an existing copy.
- `Get-PowerShellProfileHash` - reports the SHA256 of the cached profile.
- SHA256 integrity checking. The hash is always displayed, and enforced when
  `$ProfileExpectedSha256` or `-ExpectedSha256` is set.
- Explicit TLS 1.2 negotiation, which Windows PowerShell 5.1 does not always
  select by default.
- `PS_SKIP_PROFILE` environment variable to bypass profile loading when
  debugging.
- Graceful degradation: a profile that throws yields a bare working session and
  a warning rather than a broken shell.

### Security

- Closes an arbitrary code execution exposure. The previous loader executed the
  contents of a `raw.githubusercontent.com` URL in every shell on every machine,
  unpinned and unverified. Because a released GitHub username can be claimed by
  anyone, that path could have been taken over by a third party after an account
  rename. Trust is now established at update time, against a reviewable hash.

### Fixed

- Replaced PowerShell 7's null-coalescing operator (`??`) in the profile with an
  explicit `ContainsKey` check. It was a parse error under Windows PowerShell
  5.1, which the profile is expected to support.
- Repointed the source URL from the retired `bigjoestretch/public` repository to
  `bigjoestretch/powershell-toolkit`, and removed the percent-encoded path.
- Converted console output from emoji to ASCII status markers per the repository
  naming conventions.

---

## [1.0.0]

### Added

- Initial profile loader. Downloaded `Microsoft.PowerShell_profile.ps1` from
  GitHub on each shell start and dot-sourced it.
- Profile providing module bootstrapping, a custom prompt with battery, CPU and
  uptime indicators, timezone abbreviation, and a session greeting banner.
