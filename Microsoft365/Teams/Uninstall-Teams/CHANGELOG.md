# Changelog

All notable changes to this project are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [1.1.0] - 2026-07-23

Migrated from the private `Intune-Scripts` archive and corrected on the way in.

### Fixed

- **The file began with a byte-order mark rendered as stray characters**, which is invalid
  at the top of a script. Rewritten as clean ASCII.
- **Replaced `Get-WmiObject Win32_Product`** for locating the machine-wide installer.
  Enumerating that class runs a full MSI consistency check against every installed product
  and can trigger unexpected repairs. It now filters the same provider by name via
  `Get-CimInstance`.
- The uninstall assumed elevation. It now checks, and falls back to removing only the
  current user's client with a warning rather than failing.
- The MSI `Uninstall()` return value was never checked.

### Added

- Comment-based help with the standard remote-execution block.
- `-WhatIf` support and a `-SkipMachineWide` switch.
- Scope note distinguishing classic Teams (handled) from new Teams 2.x (not handled).

### Changed

- Renamed from `Uninstall_Microsoft_Teams.ps1` to `Uninstall-Teams.ps1`.

---

## [1.0.0]

### Added

- Initial version in the private archive.
