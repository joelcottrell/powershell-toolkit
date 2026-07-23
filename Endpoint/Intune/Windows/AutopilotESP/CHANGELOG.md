# Changelog

All notable changes to this project are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [1.1.0] - 2026-07-23

Migrated from the private `Intune-Scripts` archive.

### Changed

- Relocated from `PowerShell/UpdateOS/Get-EspDetectionOption/` to a dedicated
  `AutopilotESP/` project, separating it from the third-party UpdateOS app it pairs with.
- Tightened the explorer.exe WMI filter from a `like` match to an exact `Name =` match and
  added a `break` once the ESP account is found.
- Added comment-based help with the standard remote-execution block, and a scope note that
  the `defaultuser0`/`defaultuser1` convention is an undocumented Autopilot detail.

### Added

- Initial migration. Logic is unchanged: the script still reports `True` during the ESP
  phase and `False` otherwise.

---

## [1.0.0]

### Added

- Initial version in the private archive.
