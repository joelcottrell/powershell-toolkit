# Changelog

All notable changes to this project are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [1.1.0] - 2026-07-23

### Changed

- Replaced a corporate support address in the compliance message with a neutral placeholder.
- Normalised the compliance policy definition extension from `.JSON` to `.json`.
- Relocated from `Intune/Windows/Compliance/Cisco Umbrella` to `Endpoint/Intune/Windows/Compliance/Cisco-Umbrella` as part of the repository restructure. Raw URLs built on the previous path no longer resolve; the pre-reorg state is preserved at tag `v1.0-pre-reorg`.
- Renamed `Detect-Cisco-Umbrella.JSON` to `Detect-CiscoUmbrella.json` to match the approved `Verb-Noun` naming convention.
- Renamed `Detect-Cisco-Umbrella.ps1` to `Detect-CiscoUmbrella.ps1` to match the approved `Verb-Noun` naming convention.
- Repointed the repository URLs in the script headers following the GitHub account rename from `bigjoestretch` to `joelcottrell`.

## [1.0.0]

### Added

- Initial release.
