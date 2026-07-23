# Disable the Run command in Windows using Microsoft Intune Proactive Remediations

# Update Notes

## 18 March 2025
- Initial development

# Required PowerShell Modules and Microsoft Graph Permissions

This script uses Microsoft PowerShell.

# Microsoft Graph Permissions

No Microsoft graph permissions are needed to run this PowerShell script.

# Usage

When the script is run, this Microsoft Intune Proactive Remeidation script detects and remediates a wWindows registry entry. It attempts to detect whether a specific registry key exists on the local Windows device. If the specific registry key is not found (using the detection script), then the remediation script will proceed with creating the specific registry key on the Windows device.
