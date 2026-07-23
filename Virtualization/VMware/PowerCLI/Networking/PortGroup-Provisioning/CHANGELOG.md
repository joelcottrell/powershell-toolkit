# Changelog

All notable changes to this project are documented here.

## [1.4.0] - 2026-07-22

### Changed

- Aligned the package with the existing `powershell-toolkit` repository structure.
- Changed the repository path to `VMWare/PowerCLI/Networking/PortGroup-Provisioning`.
- Moved both primary scripts directly into the project root for easier discovery.
- Updated relative `Config` and `Logs` path handling for the new script location.
- Updated documentation, examples, and Pester tests for the revised layout.
- Standardized author attribution as Joel Cottrell.

## [1.3.0] - 2026-07-21

### Added

- GitHub-ready project folder structure.
- Separate `Config`, `Docs`, `Examples`, `Tests`, and `Logs` folders.
- Example CSV templates and ignored runtime CSV files.
- Project README, CSV reference, operational notes, usage examples, and static Pester tests.

### Changed

- Scripts resolve CSV files from the relative project `Config` folder.
- Scripts write logs to the relative project `Logs` folder.
- Missing CSV errors explain how to copy the included example template.

## [1.2.0] - 2026-07-21

### Added

- CSV preview and Y/N confirmation.
- Optional `-Force` parameter.
- Detailed progress, logging, summaries, and existing-object warnings.

## [1.1.0] - 2026-07-21

### Added

- Relative paths and expanded error handling.

## [1.0.0] - 2026-07-21

- Initial version.
