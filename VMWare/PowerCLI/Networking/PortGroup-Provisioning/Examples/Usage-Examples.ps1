<#
.SYNOPSIS
    Usage examples for the VMware network provisioning scripts.

.NOTES
    Author : Joel Cottrell
    Run these examples from the PortGroup-Provisioning project folder.
#>

# Prepare local runtime CSV files from the committed templates.
Copy-Item .\Config\portgroups.example.csv .\Config\portgroups.csv
Copy-Item .\Config\vdsportgroups.example.csv .\Config\vdsportgroups.csv

# Preview standard vSwitch and port-group processing.
.\New-StandardSwitchPortGroups.ps1 `
    -vCenter 'vcenter.example.com' `
    -ClusterName 'Production-Cluster' `
    -WhatIf

# Run standard networking interactively after reviewing the WhatIf output.
.\New-StandardSwitchPortGroups.ps1 `
    -vCenter 'vcenter.example.com' `
    -ClusterName 'Production-Cluster'

# Preview distributed port-group processing.
.\New-DistributedPortGroups.ps1 `
    -vCenter 'vcenter.example.com' `
    -WhatIf

# Approved unattended execution using an already reviewed CSV.
.\New-DistributedPortGroups.ps1 `
    -vCenter 'vcenter.example.com' `
    -Force
