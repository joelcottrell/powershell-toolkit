# Changelog

All notable changes to this project are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [1.1.0] - 2026-07-23

Migrated from the private `Intune-Scripts` archive and corrected on the way in.

### Fixed

- **The script had a stray closing brace and would not parse.** An extra `}` after
  `Remove-PSDrive` left the file syntactically invalid.
- The `HKU:` drive was mapped but only removed on the success path; it now unmaps in a
  `finally` block.
- Profile enumeration removed only `Public`; it now also skips `Default`, `Default User`,
  and `All Users`, which have no interactive Zoom install and no resolvable SID.
- Process termination and registry removal ran even when Zoom was not installed for a
  profile; both are now inside the per-profile guard.

### Added

- Comment-based help with the standard remote-execution block.
- Elevation check that exits before making changes.
- `-WhatIf` support and a `-MarkerRoot` parameter.
- Scope note that the machine-wide Zoom MSI is not handled by this per-user script.

### Changed

- Renamed from `Zoom-Uninstall.ps1` to `Uninstall-Zoom.ps1` (`Uninstall` is the approved
  verb; the noun follows it).

---

## [1.0.0] - 2023-03-10

### Added

- Initial version in the private archive.
