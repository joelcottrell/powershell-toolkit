<#
.NOTES
    Filename: Detect-Local_Admin_Account.ps1
    Version: 1.0
    Author: Joel Cottrell
    Requires: PowerShell v5 
    Copyright: GPLv3
	Tags: intune endpoint MEM local admin
 
.LICENSEURI
https://github.com/bigjoestretch/public/blob/main/LICENSE

.PROJECTURI
https://github.com/bigjoestretch/public/blob/main/Intune/Windows/Proactive%20Remediations/Create%20Local%20Admin%20Account

.ICONURI

.EXTERNALMODULEDEPENDENCIES

.REQUIREDSCRIPTS 

.EXTERNALSCRIPTDEPENDENCIES

.RELEASENOTES
v1.0 - 23/05/23 - Initial release of this script.

.SYNOPSIS
    This script package will attempt to detect a local administrator account on the targeted devices.
    This script is used as detection script with Proactive Remediations in the Microsoft Intune admin center.

.DESCRIPTION
    Manage a local administrator account in Windows, which currently consists of:
    - XXXX-XXXXX

.LINK
    Inspiration in creating this was provide y steps found in this link:
    
    https://cloudinfra.net/create-a-local-admin-using-intune-and-powershell/

.EXAMPLE
Detect-Local_Admin_Account.ps1

#>

# Discovery script
# Replace the XXXX-XXXXX with the name of the actual local admin account"
$userName = "XXXX-XXXXX"
$Userexist = (Get-LocalUser).Name -Contains $userName
if ($userexist) { 
  Write-Host "$userName exist" 
  Exit 0
} 
Else {
  Write-Host "$userName does not Exists"
  Exit 1
}
