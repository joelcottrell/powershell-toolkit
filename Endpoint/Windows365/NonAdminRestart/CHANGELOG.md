# Changelog

All notable changes to this project are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [1.1.0] - 2026-07-23

Migrated from the private `Intune-Scripts` archive and corrected on the way in.

### Fixed

- **The script was not idempotent.** It appended the SID to `SeShutdownPrivilege`
  unconditionally, so every run added another duplicate entry to local security policy. It
  now checks whether the principal already holds the right and exits without writing.
- **Temporary files leaked on failure.** The policy export was removed only on the success
  path, and `secedit.sdb` was written to the current working directory and never cleaned
  up. Both now use randomised names in the temp directory and are removed in a `finally`
  block.
- **The exit code of `secedit /configure` was never checked**, so a failed policy import
  was reported as success.
- The principal was hardcoded to `Users` and resolved after the policy export had already
  begun. It is now a parameter, resolved to a SID before anything is touched, so a bad
  value fails immediately.
- The rewritten policy file is now written as Unicode, which `secedit` expects.

### Added

- `-Principal` parameter, defaulting to the local `Users` group.
- `-WhatIf` support.
- Elevation check that exits before making changes rather than failing part-way.
- Scope notes recording that a Group Policy or Intune baseline defining the same user right
  overrides this change at the next policy refresh.

### Changed

- Renamed from `CloudPC_Allow_Restart_NonAdmins.ps1` to `Grant-ShutdownPrivilege.ps1`.
  `Grant` is an approved PowerShell verb and the name now describes the right being
  granted rather than the scenario that prompted it.

---

## [1.0.0]

### Added

- Initial version in the private archive.
