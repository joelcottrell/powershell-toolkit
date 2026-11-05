# Changelog

All notable changes to this project are documented here.

The format is based on Keep a Changelog and this project follows Semantic Versioning.

---

## [1.0.0] - 2026-11-05

### Added

- Initial public release of DesktopPolicy-Guard.
- Windows service architecture using a pinned WinSW wrapper.
- Continuous machine-level registry enforcement.
- Loaded-user registry enforcement through HKEY_USERS.
- Optional Public Desktop and user Desktop shortcut cleanup.
- JSON-driven configuration with a safe tracked example.
- Audit-only and run-once validation modes.
- Rotating logs and a JSON status heartbeat.
- Installer, service engine, uninstaller, audit helper, documentation, and Pester tests.

### Security

- No organization-specific identifiers or credentials are stored in the project.
- No executable binaries are committed to the repository.
- Shortcut deletion is disabled in the tracked example configuration.
