# Changelog

All notable changes to this project are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [1.1.0] - 2026-07-23

### Changed

- Converted script content to ASCII per the repository naming conventions.
- Relocated from `Intune/Windows/Proactive Remediations/Microsoft Store Forced Auto Update` to `Endpoint/Intune/Windows/ProactiveRemediations/MicrosoftStore-ForcedAutoUpdate` as part of the repository restructure. Raw URLs built on the previous path no longer resolve; the pre-reorg state is preserved at tag `v1.0-pre-reorg`.
- Renamed `Detect-Microsoft_Store_Auto_Update.ps1` to `Detect-MicrosoftStoreAutoUpdate.ps1` to match the approved `Verb-Noun` naming convention.
- Renamed `Remediate-Microsoft_Store_Auto_Update.ps1` to `Remediate-MicrosoftStoreAutoUpdate.ps1` to match the approved `Verb-Noun` naming convention.
- Repointed the repository URLs in the script headers following the GitHub account rename from `bigjoestretch` to `joelcottrell`.

## [1.0.0]

### Added

- Initial release.
