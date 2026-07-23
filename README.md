![PowerShell](https://img.shields.io/badge/PowerShell-5391FE?style=for-the-badge&logo=powershell&logoColor=white)
![License](https://img.shields.io/github/license/joelcottrell/powershell-toolkit?style=for-the-badge)
![GitHub last commit](https://img.shields.io/github/last-commit/joelcottrell/powershell-toolkit?style=for-the-badge)
![GitHub issues](https://img.shields.io/github/issues/joelcottrell/powershell-toolkit?style=for-the-badge)

# PowerShell Toolkit

PowerShell automation for enterprise IT administration. Built from 20 years of hands-on
experience in healthcare IT environments, these scripts solve real-world challenges across
Microsoft and VMware infrastructure.

These aren't theoretical examples - they're battle-tested tools from actual production
environments, shared freely with the IT community.

---

## Repository index

| Domain | Technologies | Description | |
| --- | --- | --- | --- |
| **Endpoint** | Intune | Device compliance, proactive remediations, Win32 apps, device scripts | [Browse](./Endpoint/README.md) |
| **Virtualization** | VMware, PowerCLI | vSphere networking, host authentication, reporting | [Browse](./Virtualization/README.md) |
| **Windows** | Server, Client, Common | OS administration, diagnostics, deployment | [Browse](./Windows/README.md) |
| **Shared** | - | Reusable functions and the centrally managed PowerShell profile | [Browse](./Shared/README.md) |
| **Identity** | Active Directory, Entra ID, Microsoft Graph | Directory and identity administration | [Browse](./Identity/README.md) |
| **Microsoft365** | Exchange, SharePoint, Teams, Tenant | Workload and tenant administration | [Browse](./Microsoft365/README.md) |
| **Azure** | Automation | Runbooks and cloud automation | [Browse](./Azure/README.md) |

**32 scripts across 20 projects.** Coverage is uneven by design - `Endpoint/` is the most
developed, while `Identity/`, `Microsoft365/`, and `Azure/` are scaffolded and awaiting
content. Empty category folders are deliberate structure, not abandonment.

### Start here

**[PortGroup-Provisioning](./Virtualization/VMware/PowerCLI/Networking/PortGroup-Provisioning/README.md)**
is the reference implementation for this repository. It provisions vSphere standard and
distributed port groups from validated CSV, and demonstrates the full Tier 2 pattern:
configuration review before any write, structured logging, idempotent behaviour, Pester
tests, and documented scope boundaries.

---

## Repository structure

```
powershell-toolkit/
├── _Template/              # Tier 1 and Tier 2 project skeletons
├── docs/                   # Conventions, templates, and the reorg plan
├── Azure/
│   └── Automation/         # Azure Automation runbooks
├── Endpoint/
│   └── Intune/             # Device management across Windows and macOS
├── Identity/
│   ├── ActiveDirectory/
│   ├── EntraID/
│   └── MicrosoftGraph/
├── Microsoft365/
│   ├── Exchange/
│   ├── SharePoint/
│   ├── Teams/
│   └── Tenant/             # Cross-workload and tenant-wide
├── Shared/                 # Reusable across domains
├── Virtualization/
│   └── VMware/
│       └── PowerCLI/
│           ├── Authentication/
│           ├── Hosts/
│           ├── Networking/
│           ├── Reporting/
│           └── VirtualMachines/
└── Windows/
    ├── Client/             # Workstation-specific
    ├── Common/             # Runs unmodified on both
    └── Server/             # Server-specific
```

Two design notes worth stating. `Endpoint/` sits outside `Windows/` because Intune is a
management plane spanning Windows, macOS, iOS, and Android - filing it under an OS would
be wrong. `Windows/Common/` exists so OS-agnostic scripts have an obvious home instead of
becoming an arbitrary judgment call every time.

---

## Getting started

### Prerequisites

PowerShell 5.1 or later. Scripts are written against 5.1 and verified to parse under it;
PowerShell 7+ works for most.

| Module | Install | Needed for |
| --- | --- | --- |
| `VMware.PowerCLI` | `Install-Module VMware.PowerCLI -Scope CurrentUser` | Virtualization |
| `Microsoft.Graph` | `Install-Module Microsoft.Graph -Scope CurrentUser` | Identity, Microsoft 365 |
| `ExchangeOnlineManagement` | `Install-Module ExchangeOnlineManagement -Scope CurrentUser` | Exchange |
| `Microsoft.Online.SharePoint.PowerShell` | `Install-Module Microsoft.Online.SharePoint.PowerShell -Scope CurrentUser` | SharePoint |
| `ActiveDirectory` | Windows feature (RSAT) | Active Directory |

Each project README lists its own requirements. Install only what you need.

### Clone

```powershell
git clone https://github.com/joelcottrell/powershell-toolkit.git
```

Then read the project README before running anything.

---

## Remote execution

Every script carries a header documenting three ways to run it straight from GitHub
without cloning. In short:

| Option | Pattern | Use when |
| --- | --- | --- |
| 1 | `Invoke-Expression` against a raw URL | Never, in production |
| 2 | Download, review, then run | **Default recommendation** |
| 3 | Scheduled task that re-downloads each run | Only with a pinned tag |

> **Security caveat.** Option 1 executes remote code without review - convenient, and
> exactly the pattern security teams flag. Option 3 compounds it by re-fetching on every
> run, so a repository compromise propagates immediately with no window to catch it.
>
> **For anything touching production, pin the URL to a release tag rather than `main`.**
> A branch changes under you; a tag does not.

The full pattern is in the header of any script - see
[PortGroup-Provisioning](./Virtualization/VMware/PowerCLI/Networking/PortGroup-Provisioning/README.md)
for a worked example, or [docs/PROJECT-TEMPLATE.md](./docs/PROJECT-TEMPLATE.md) for the
reasoning.

---

## Conventions

New projects start from a skeleton in [`_Template/`](./_Template/README.md).

- [Naming conventions](./docs/NAMING-CONVENTIONS.md) - folder and file naming, the
  no-spaces rule, approved verbs, and the two documented exceptions
- [Project template guide](./docs/PROJECT-TEMPLATE.md) - tier selection, the mandatory
  script header, and what a project README owes its reader
- [Development workflow](./docs/WORKFLOW.md) - the publish loop, working across two machines,
  and why git (not OneDrive) is the sync layer

Two rules are absolute: **no spaces in any path** (raw URLs percent-encode them and fail
silently), and **no credentials or tenant identifiers in any script** - those become
mandatory parameters.

---

## Best practices

- **Always test in a non-production environment first**
- Review and understand what a script does before running it
- Confirm you have appropriate permissions for the target environment
- Back up before running anything that makes changes
- Follow your organisation's change management procedures

---

## Contributing

Found a bug? Have an improvement? Contributions are welcome.

1. Fork the repository
2. Create a feature branch
3. Make your changes, following [the conventions](./docs/NAMING-CONVENTIONS.md)
4. Submit a pull request

---

## License

Licensed under GPL-3.0 - see [LICENSE](./LICENSE).

---

## About the author

**Joel Cottrell** - Systems Administrator/Engineer with 20 years of experience in
enterprise IT infrastructure, specialising in Microsoft technologies and automation for
healthcare environments.

- GitHub: [@joelcottrell](https://github.com/joelcottrell)
- LinkedIn: [joelcottrell](https://www.linkedin.com/in/joelcottrell)

---

## Disclaimer

THE SOFTWARE (SCRIPTS) ARE PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A
PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
OTHER DEALINGS IN THE SOFTWARE.

**Always test scripts in a development environment before using in production.**

---

## Support

If you find these scripts helpful, please:

- ⭐ Star this repository
- 🐛 Report issues you encounter
- 💡 Share your improvements
- 📢 Tell other IT professionals

---

![VMware](https://img.shields.io/badge/VMware-607078?style=flat&logo=vmware&logoColor=white)
![Microsoft 365](https://img.shields.io/badge/Microsoft_365-0078D4?style=flat&logo=microsoft&logoColor=white)
![Azure](https://img.shields.io/badge/Azure-0089D6?style=flat&logo=microsoft-azure&logoColor=white)
![Active Directory](https://img.shields.io/badge/Active_Directory-0078D4?style=flat&logo=windows&logoColor=white)
![Intune](https://img.shields.io/badge/Intune-0078D4?style=flat&logo=microsoft&logoColor=white)
