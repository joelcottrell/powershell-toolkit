# VMware PowerCLI - Port Group Provisioning

This VMware PowerCLI project provides scripts for deploying standard and distributed port groups from validated CSV configuration files.

✅ Creates missing standard vSwitches across all eligible ESXi hosts in a selected cluster

🌐 Creates standard and distributed port groups from CSV configuration

⚠️ Detects existing switches, port groups, missing switches, and VLAN mismatches

📊 Displays detailed console progress for each ESXi host and task

📝 Writes timestamped success, warning, and failure details to a relative `Logs` folder

---

## Standard vSwitch and Port Group Script

[New-StandardSwitchPortGroups.ps1](New-StandardSwitchPortGroups.ps1)

This script processes each eligible ESXi host in a selected cluster and applies the standard networking configuration defined in `portgroups.csv`.

### 🔧 Requirements

- Windows PowerShell 5.1 or PowerShell 7+
- VMware PowerCLI or VCF PowerCLI
- Network connectivity to vCenter
- Permission to read clusters and ESXi hosts
- Permission to create standard vSwitches and port groups
- A reviewed `portgroups.csv` file in the `Config` folder

### 📄 CSV Configuration

Create the working CSV file from the included example:

```powershell
Copy-Item `
    .\Config\portgroups.example.csv `
    .\Config\portgroups.csv
```

The CSV requires the following columns:

```csv
vSwitchName,PortGroup,VlanID
vSwitch1,Production,100
vSwitch1,Development,200
vSwitch2,Backup,300
```

### ▶️ Usage

Run interactively:

```powershell
.\New-StandardSwitchPortGroups.ps1
```

Preview the operation without making changes:

```powershell
.\New-StandardSwitchPortGroups.ps1 -WhatIf
```

Provide the vCenter and cluster names as parameters:

```powershell
.\New-StandardSwitchPortGroups.ps1 `
    -vCenter "vcenter.domain.com" `
    -ClusterName "Production-Cluster"
```

Skip the interactive CSV confirmation only after the configuration has already been reviewed:

```powershell
.\New-StandardSwitchPortGroups.ps1 `
    -vCenter "vcenter.domain.com" `
    -ClusterName "Production-Cluster" `
    -Force
```

### ⚙️ Existing Object Behavior

- Existing standard vSwitches are displayed and logged as warnings.
- Existing standard vSwitches are reused so missing port groups can still be created.
- Existing port groups are skipped and logged.
- Existing port groups with a VLAN that differs from the CSV value generate a warning.
- VLAN mismatches are not corrected automatically.

---

## Distributed Port Group Script

[New-DistributedPortGroups.ps1](New-DistributedPortGroups.ps1)

This script creates missing distributed port groups on existing VMware vSphere Distributed Switches.

### 🔧 Requirements

- Windows PowerShell 5.1 or PowerShell 7+
- VMware PowerCLI or VCF PowerCLI
- Network connectivity to vCenter
- Existing vSphere Distributed Switches
- Permission to create distributed port groups
- A reviewed `vdsportgroups.csv` file in the `Config` folder

### 📄 CSV Configuration

Create the working CSV file from the included example:

```powershell
Copy-Item `
    .\Config\vdsportgroups.example.csv `
    .\Config\vdsportgroups.csv
```

The CSV requires the following columns:

```csv
vdsName,PortGroup,VlanID
Production-VDS,Production-App,100
Production-VDS,Production-Web,200
Backup-VDS,Backup-Network,300
```

### ▶️ Usage

Run interactively:

```powershell
.\New-DistributedPortGroups.ps1
```

Preview the operation:

```powershell
.\New-DistributedPortGroups.ps1 -WhatIf
```

Provide the vCenter name as a parameter:

```powershell
.\New-DistributedPortGroups.ps1 `
    -vCenter "vcenter.domain.com"
```

### ⚙️ Existing Object Behavior

- Existing distributed port groups are skipped and logged.
- Existing port groups with a VLAN that differs from the CSV value generate a warning.
- Missing distributed switches are logged and skipped.
- VLAN mismatches are not corrected automatically.

---

## 📂 Project Structure

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

---

## 📋 CSV Review and Confirmation

Before connecting to vCenter, each script:

1. Finds the required CSV file in the relative `Config` folder.
2. Validates the required columns and values.
3. Displays the complete configuration in the PowerShell console.
4. Shows the number of configuration rows and unique switches.
5. Prompts the operator to type `Y` or `N`.

Example:

```text
==============================================================================
CSV CONFIGURATION REVIEW
==============================================================================

I successfully read and validated the CSV file:
  C:\GitHub\powershell-toolkit\VMWare\PowerCLI\Networking\
  PortGroup-Provisioning\Config\portgroups.csv

Configuration rows found : 3
Unique vSwitches found   : 2

vSwitch   Port Group    VLAN ID
-------   ----------    -------
vSwitch1  Development   200
vSwitch1  Production    100
vSwitch2  Backup        300

Would you like to proceed with this configuration?

Type Y and press Enter for Yes.
Type N and press Enter for No.
```

Selecting `N` ends the script before connecting to vCenter or making VMware changes.

---

## 📊 Console Progress

The scripts display console progress while processing the configuration.

The progress display includes:

- Current ESXi host or distributed port group
- Current host number and total host count
- Current task and total task count
- Switch or port group currently being evaluated
- Percentage complete

Console step banners also identify the active phase, such as:

```text
==============================================================================
STEP 5 OF 6 - CREATING AND VALIDATING STANDARD NETWORKING
==============================================================================
```

---

## 📁 Logging

Each execution automatically creates a timestamped log in the relative `Logs` folder.

```text
Logs/
├── StandardNetworkDeployment_YYYYMMDD_HHMMSS.log
└── DistributedPortGroupDeployment_YYYYMMDD_HHMMSS.log
```

The logs include:

- Script initialization details
- CSV path and validation results
- vCenter connection status
- ESXi host discovery
- Existing switch and port-group warnings
- Successful object creation
- VLAN mismatch warnings
- Per-object failures
- Completion statistics
- vCenter disconnection status

The `Logs` folder moves with the project, so the script paths do not need to be changed when the project is relocated.

---

## 🛡️ Safety Features

- CSV file existence validation
- Required-column validation
- Empty-value detection
- VLAN range validation
- Duplicate configuration detection
- Human-readable CSV preview
- Interactive Y/N confirmation
- `-WhatIf` support
- `-Confirm` support
- Existing-object detection
- VLAN mismatch warnings
- Per-object exception handling
- Detailed progress reporting
- Timestamped logging
- Guaranteed vCenter disconnection during cleanup

---

## ⚠️ Important Scope Notes

The standard vSwitch script does not currently configure:

- Physical uplink assignment
- MTU
- NIC teaming and failover order
- Load-balancing policies
- Security policies
- Traffic shaping

A newly created standard vSwitch without a physical adapter may not provide external network connectivity.

The distributed port-group script currently creates standard access VLAN port groups. It does not configure:

- VLAN trunk ranges
- Private VLANs
- Advanced teaming policies
- Distributed port-group security settings
- Traffic shaping

Always review the planned configuration and test with `-WhatIf` before making changes.

---

## 🧪 Testing

The included Pester tests validate:

- Expected project files and folders
- CSV template headers
- Relative path usage
- Absence of obvious hardcoded user-profile paths

Run the repository tests with:

```powershell
Invoke-Pester .\Tests\Repository.Tests.ps1
```

The included tests do not connect to vCenter or create VMware objects.

---

## 📚 Additional Documentation

- [CSV Reference](Docs/CSV-Reference.md)
- [Operational Notes](Docs/Operational-Notes.md)
- [Repository Integration](Docs/Repository-Integration.md)
- [Usage Examples](Examples/Usage-Examples.ps1)
- [Changelog](CHANGELOG.md)

---

## 👤 Author

**Joel Cottrell**

PowerShell automation for enterprise infrastructure administration.

---

## 📜 License

This project inherits the GPL-3.0 license from the repository root.

---

> Always test scripts in a non-production environment before using them in production.
