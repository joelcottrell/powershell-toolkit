# Changelog

All notable changes to this project are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [2.0.0] - 2026-07-23

### Security

- **Removed a hardcoded Datto RMM SiteID and platform name.** The SiteID is the only token
  required to download an agent installer bound to a specific tenant site, and it was
  committed in a public repository. It is now a mandatory, GUID-validated parameter with no
  default, alongside `-Platform`.
- Note that the previous value remains in this repository's git history and in the
  `v1.0-pre-reorg` tag. Removing it from the working tree does not retract it. The site
  token should be regenerated.

### Changed

- **Breaking.** `Install-DattoRMMAgent.ps1` now requires `-Platform` and `-SiteID`. Update
  the Intune install command accordingly; the README documents where to find both values.
- Removed the former employer's name from the script filename, synopsis, and description.

- Relocated from `Intune/Windows/Win32Apps/Datto RMM/Windows` to `Endpoint/Intune/Windows/Win32Apps/Datto-RMM/Windows` as part of the repository restructure. Raw URLs built on the previous path no longer resolve; the pre-reorg state is preserved at tag `v1.0-pre-reorg`.
- Renamed `IntelyCare_Datto_RMM_Agent_Install-Vidal.ps1` to `Install-DattoRMMAgent.ps1` to match the approved `Verb-Noun` naming convention.
- Renamed `Datto_RMM_Agent_Uninstall.cmd` to `Uninstall-DattoRMMAgent.cmd` to match the approved `Verb-Noun` naming convention.
- Repointed the repository URLs in the script headers following the GitHub account rename from `bigjoestretch` to `joelcottrell`.

## [1.0.0]

### Added

- Initial release.
