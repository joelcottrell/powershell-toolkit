# VMware PowerCLI Network Port Group Provisioning

PowerShell and VMware PowerCLI scripts for deploying standard vSwitch port groups across ESXi hosts in a cluster and distributed port groups on existing vSphere Distributed Switches.

## Included scripts

| Script | Purpose |
|---|---|
| `New-StandardSwitchPortGroups.ps1` | Creates missing standard vSwitches and standard port groups on each eligible ESXi host in a selected cluster. |
| `New-DistributedPortGroups.ps1` | Creates missing distributed port groups on existing vSphere Distributed Switches. |

Both scripts validate their CSV input, display the planned configuration, require confirmation, support `-WhatIf`, write detailed logs, warn about existing objects, and disconnect from vCenter when processing completes.

## Project structure

```text
PortGroup-Provisioning/
├── New-StandardSwitchPortGroups.ps1
├── New-DistributedPortGroups.ps1
├── Config/
│   ├── portgroups.example.csv
│   └── vdsportgroups.example.csv
├── Docs/
│   ├── CSV-Reference.md
│   ├── Operational-Notes.md
│   └── Repository-Integration.md
├── Examples/
│   └── Usage-Examples.ps1
├── Tests/
│   └── Repository.Tests.ps1
├── Logs/
│   └── .gitkeep
├── .gitignore
├── CHANGELOG.md
└── README.md
```

## Requirements

- Windows PowerShell 5.1 or PowerShell 7
- VMware PowerCLI or VCF PowerCLI
- Network connectivity to vCenter
- Appropriate vCenter permissions for the requested operation
- A reviewed CSV configuration file in the `Config` folder

## Initial setup

Clone the repository and navigate to the project:

```powershell
Set-Location .\VMWare\PowerCLI\Networking\PortGroup-Provisioning
```

Copy the example CSV templates to their runtime filenames:

```powershell
Copy-Item .\Config\portgroups.example.csv .\Config\portgroups.csv
Copy-Item .\Config\vdsportgroups.example.csv .\Config\vdsportgroups.csv
```

Update the copied CSV files with values for your environment. The runtime CSV files are excluded by `.gitignore` so environment-specific network information is not committed accidentally.

## Recommended first run

Preview the standard vSwitch deployment without making changes:

```powershell
.\New-StandardSwitchPortGroups.ps1 -WhatIf
```

Preview the distributed port-group deployment:

```powershell
.\New-DistributedPortGroups.ps1 -WhatIf
```

The scripts display the validated CSV configuration and prompt for approval before connecting to vCenter. Use `-Force` only for an already reviewed unattended execution.

## CSV formats

### Standard vSwitch and port groups

```csv
vSwitchName,PortGroup,VlanID
vSwitch1,Production,100
vSwitch1,Development,200
vSwitch2,Backup,300
```

### Distributed port groups

```csv
vdsName,PortGroup,VlanID
Production-VDS,Production-App,100
Production-VDS,Production-Web,200
Backup-VDS,Backup-Network,300
```

See [Docs/CSV-Reference.md](Docs/CSV-Reference.md) for field definitions and validation behavior.

## Existing object behavior

- An existing standard vSwitch is reused, allowing missing port groups to be created on it.
- An existing port group is skipped and logged as a warning.
- When an existing port group's VLAN differs from the CSV value, the script warns and does not change it automatically.
- A missing distributed switch is logged and skipped.

## Logging

Each run creates a timestamped log under the relative `Logs` folder. Logs are excluded from source control.

```text
Logs/
├── StandardNetworkDeployment_YYYYMMDD_HHMMSS.log
└── DistributedPortGroupDeployment_YYYYMMDD_HHMMSS.log
```

## Safety features

- CSV existence, required-column, empty-value, VLAN-range, and duplicate validation
- Human-readable CSV preview before connecting to vCenter
- Y/N confirmation prompt
- `-WhatIf` and `-Confirm` support
- Existing-object detection
- VLAN mismatch warnings
- Per-object exception handling
- Detailed console progress and timestamped logs
- Guaranteed vCenter disconnection in the cleanup path

## Important scope notes

The standard vSwitch script does not currently assign physical uplinks or configure MTU, NIC teaming, security policies, or traffic shaping. A newly created standard vSwitch without a physical adapter may not provide external connectivity.

The distributed script currently creates standard access VLAN port groups. VLAN trunks, private VLANs, advanced teaming, and other distributed port-group policies are outside its current scope.

## Testing

The included Pester tests validate repository structure, CSV template headers, relative-path usage, and the absence of obvious hardcoded user-profile paths. They do not connect to vCenter.

```powershell
Invoke-Pester .\Tests\Repository.Tests.ps1
```

## Author

Joel Cottrell

## License

This project inherits the GPL-3.0 license from the repository root.
