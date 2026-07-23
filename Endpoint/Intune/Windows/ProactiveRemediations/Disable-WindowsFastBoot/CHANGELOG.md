# Changelog

All notable changes to this project are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [1.1.0] - 2026-07-23

### Changed

- Relocated from `Intune/Windows/Proactive Remediations/Disable Windows Fast Boot` to `Endpoint/Intune/Windows/ProactiveRemediations/Disable-WindowsFastBoot` as part of the repository restructure. Raw URLs built on the previous path no longer resolve; the pre-reorg state is preserved at tag `v1.0-pre-reorg`.
- Renamed `Detect-Fastboot.ps1` to `Detect-WindowsFastBoot.ps1` to match the approved `Verb-Noun` naming convention.
- Renamed `Remediate-Fastboot.ps1` to `Remediate-WindowsFastBoot.ps1` to match the approved `Verb-Noun` naming convention.
- Repointed the repository URLs in the script headers following the GitHub account rename from `bigjoestretch` to `joelcottrell`.

## [1.0.0]

### Added

- Initial release.
