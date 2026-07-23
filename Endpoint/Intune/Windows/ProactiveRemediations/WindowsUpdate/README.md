Proactive remediation scripts to remove any values set in the normal WindowsUpdate policy key.

# Update Notes

## 6 September 2024
- Initial development

# Required PowerShell Modules and Microsoft Graph Permissions

This script uses Microsoft.Graph. The script only installs the Microsoft.Graph modules it needs to run this script, not the entire Microsoft.Graph module. These modules are:

- Microsoft.Graph.authentication 
- Microsoft.Graph.Identity.DirectoryManagement
- Microsoft.Graph.Users
- Microsoft.Graph.Users.Actions
- Microsoft.Graph.DeviceManagement.Actions
- Microsoft.Graph.DeviceManagement.Administration
- Microsoft.Graph.Groups
- Microsoft.Graph.DeviceManagement.Functions 


# Microsoft Graph Permissions

The account you are running the script with needs to have the following Microsoft Graph API Permissions:

- CloudPC.ReadWrite.All
- Directory.Read.All
- GroupMember.ReadWrite.All
- User.ReadWrite.All
- Organization.Read.All 

# Usage

When the script is run, 
