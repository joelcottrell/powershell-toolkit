# CLAUDE.md

Guidance for Claude Code when working in this repository. This file travels with the repo,
so it applies on any machine or surface (CLI, desktop, or claude.ai/code) that opens it.

## What this repo is

`joelcottrell/powershell-toolkit` (public) is a curated collection of PowerShell scripts for
enterprise IT administration, organised into eight domains: `Azure/`, `Endpoint/`,
`Identity/`, `Microsoft365/`, `Shared/`, `Virtualization/`, `Windows/`, plus `_Template/`
and `docs/`.

Its private companion, `joelcottrell/Intune-Scripts`, is an uncurated archive. Good scripts
get migrated out of it into this repo, copied fresh (never history-grafted, which has
carried secrets and binaries).

## The publish workflow

**When the user finishes developing a PowerShell script, offer once to publish it here** -
at the natural completion point, not as a running prompt. If they accept, run the
[`publish-to-toolkit`](.claude/skills/publish-to-toolkit/SKILL.md) skill: place it in the
right domain, rename to `Verb-Noun`, add the mandatory header, write a README and CHANGELOG
from `_Template/`, update the parent category README, verify, and open a PR.

## Rules that are absolute

- **Never push to `main`.** Work on a feature branch and open a PR.
- **No spaces in any path**, ever - scripts are served over `raw.githubusercontent.com`.
- **ASCII only in `.ps1` files** - Markdown may use emoji; scripts may not.
- **No secrets or tenant data in scripts** - tenant IDs, site tokens, org GUIDs, internal
  URLs become mandatory parameters. Never commit `.cred/.key/.pfx/.cer/.exe/.intunewin`.
- **Attribute third-party work** - credit the original author; do not present it as original.
- **Pin production consumers to a release tag**, not `main`.

## Conventions

Full detail in [`docs/NAMING-CONVENTIONS.md`](docs/NAMING-CONVENTIONS.md) and
[`docs/PROJECT-TEMPLATE.md`](docs/PROJECT-TEMPLATE.md). New projects start from
[`_Template/`](_Template/README.md). Every project has a README and a CHANGELOG. Scripts must
parse under Windows PowerShell 5.1.

## Verification before any PR

- Scripts parse under 5.1 and contain no non-ASCII characters
- No spaces in any tracked path
- Every relative markdown link resolves
- No credentials, tenant identifiers, or binaries added
