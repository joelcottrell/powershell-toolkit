# Changelog

All notable changes to this project are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [1.1.0] - 2026-07-23

### Changed

- Collapsed the `Entra ID` subfolder into the project folder; it was the only provider present and the space-bearing name was not permitted.
- Filed under `Authentication/` rather than `Hosts/`: this is vCenter authentication, not ESXi host management.
- Converted script content to ASCII and corrected the vendor casing from `VMWare` to `VMware`.
- Relocated from `VMWare/PowerCLI/Connect to External Identity Provider/Entra ID` to `Virtualization/VMware/PowerCLI/Authentication/Connect-ExternalIdentityProvider` as part of the repository restructure. Raw URLs built on the previous path no longer resolve; the pre-reorg state is preserved at tag `v1.0-pre-reorg`.
- Renamed `powercli_entra_id_connect_vcenter.ps1` to `Connect-ExternalIdentityProvider.ps1` to match the approved `Verb-Noun` naming convention.
- Repointed the repository URLs in the script headers following the GitHub account rename from `bigjoestretch` to `joelcottrell`.

## [1.0.0]

### Added

- Initial release.
