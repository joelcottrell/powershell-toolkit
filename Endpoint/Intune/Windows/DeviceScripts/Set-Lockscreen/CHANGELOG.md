# Changelog

All notable changes to this project are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [1.1.0] - 2026-07-23

Migrated from the private `Intune-Scripts` archive. Four loose scripts were consolidated
into three well-formed ones and corrected on the way in.

### Fixed

- **The detection script had a logic error that made it unreliable.** It chained
  comparisons as `($reg2 -and $reg5 -eq $true)` and `($reg1 -and $reg3 -eq "path")`, where
  operator precedence evaluates `-eq` first and never actually compares `$reg2` or `$reg1`
  to anything. Each expected value is now checked explicitly.
- **Image URLs and paths were hardcoded placeholders** (`https:\yourimageurl`,
  `yourstorageaccount.blob...`, `c:\intune`) that had to be edited in place before use.
  They are now parameters.
- The destination folder was inconsistent between scripts (`c:\intune` vs
  `C:\temp\images`), so the detection script could never match what the set script wrote.
  All three now share a single `-DestinationFolder`, defaulting to
  `C:\ProgramData\Lockscreen`.
- Set operations proceeded even when an image download failed; staging is now checked
  before any registry value is written.

### Added

- Elevation checks on the set and remove scripts.
- `-WhatIf` on set and remove.
- Comment-based help and scope notes, in particular that the Personalization CSP is
  honoured on Enterprise and Education only and is ignored on Windows Pro.

### Changed

- Consolidated `URL-SetBackgroundLockscreen.ps1` and `Local-SetBackgroundLockscreen.ps1`
  into a single `Set-Lockscreen.ps1` with `FromUrl` and `FromFile` parameter sets.
- Renamed `UninstallBackgroundLockscreen.ps1` to `Remove-Lockscreen.ps1` and
  `DynamicDetection.ps1` to `Test-Lockscreen.ps1`, both approved verbs.
- Attributed the approach to smbtothecloud.com, which the original `readme.txt` cited.

### Removed

- The company-branded variant that previously lived alongside these scripts was deleted
  from the source archive before migration and is not carried over.

---

## [1.0.0]

### Added

- Initial versions in the private archive.
