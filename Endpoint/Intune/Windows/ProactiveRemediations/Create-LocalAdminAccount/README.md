# Create a Local Admin account in Windows using Microsoft Intune Proactive Remediations

# Update Notes

## 08 May 2023
- Initial development

# Required PowerShell Modules and Microsoft Graph Permissions

This script uses Microsoft PowerShell.

# Microsoft Graph Permissions

No Microsoft graph permissions are needed to run this PowerShell script.

# Usage

When the script is run, this Microsoft Intune Proactive Remeidation script detects and remediates a local admin account on a Windows device. It attempts to detect whether a specific local admin account exists on the local Windows device. if the specific local admin account is not found (using the detection script), then the remediation script will proceed with creating the specific locl admin account on the Windows device.
