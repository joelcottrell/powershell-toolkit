<#
.NOTES
    Filename: Remediate-Local_Admin_Account.ps1
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
    This script is used as a remediation script with Proactive Remediations in the Microsoft Intune admin center.

.DESCRIPTION
    Manage the local administrator account in Windows, which currently consists of:
    - XXXX-XXXXX

.LINK
    https://cloudinfra.net/create-a-local-admin-using-intune-and-powershell/

.EXAMPLE
Remediate-Local_Admin_Account.ps1

#>

# Remediation script
# Replace the XXXX-XXXXX with the name of the actual local admin account"
$userName = "XXXX-XXXXX"
$userexist = (Get-LocalUser).Name -Contains $userName
if($userexist -eq $false) {
  try{ 
     New-LocalUser -Name $username -FullName $username -Description "Company's Local Admin user account" -NoPassword | Set-LocalUser -PasswordNeverExpires 1
     Exit 0
   }   
  Catch {
     Write-error $_
     Exit 1
   }
} 
