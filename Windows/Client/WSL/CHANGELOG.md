# Changelog

All notable changes to this project are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [1.1.0] - 2026-07-23

Migrated from the private `Intune-Scripts` archive. Brought up to repository conventions
and corrected on the way in.

### Fixed

- **`Set-WSLFeature.ps1` could not be parsed.** Its param block declared a bare `[switch]`
  type with no variable name, which is a syntax error. It also used two mutually exclusive
  `-Enable`/`-Disable` switches, so calling it with both was accepted and silently applied
  only one. Replaced with a single mandatory `-State` parameter validated to
  `Enabled`/`Disabled`.
- **Both restart messages used typographic quotation marks** rather than ASCII quotes. The
  characters were literal, so `shutdown /c` received a malformed argument and the restart
  comment was never passed correctly.
- **`Install-WSL2Ubuntu.ps1` never checked for elevation.** The elevation function was
  present but commented out and never called, so a non-elevated run failed part-way
  through. All three scripts now verify elevation and exit before changing anything.
- The install scheduled a restart unconditionally, including after a failed
  `wsl --install`. It now checks the exit code first.
- The uninstall removed a hardcoded AppX package name that changes between Ubuntu releases;
  it now matches by pattern and skips cleanly when nothing is found.
- The MSI uninstall log was written to the current working directory. It now goes to the
  temp directory and the path is reported.

### Added

- `-WhatIf` support on all three scripts.
- Confirmation before `wsl --unregister`, which permanently destroys the distribution
  filesystem. `ConfirmImpact` is `High`; `-Force` bypasses it for unattended use.
- `-NoRestart` and `-RestartDelaySeconds` so the mandatory restart can be controlled.
- `-Distribution` on the uninstall, replacing the hardcoded `ubuntu`.
- Full comment-based help with the standard remote-execution block.
- Scope notes recording what these scripts deliberately do not do, in particular that the
  Virtual Machine Platform feature is left alone because Hyper-V, Docker Desktop, and
  Windows Sandbox depend on it.

### Changed

- Renamed to `Verb-Noun` form: `Install-WSL2-Ubuntu.ps1` to `Install-WSL2Ubuntu.ps1`,
  `Uninstall-WSL2-Ubuntu.ps1` to `Uninstall-WSL2Ubuntu.ps1`, and
  `Windows_SubSystem_for_Linux.ps1` to `Set-WSLFeature.ps1`.
- Attributed `Set-WSLFeature.ps1` to David Brook, its original author.

---

## [1.0.0] - 2022-10-13

### Added

- Initial versions in the private archive.
