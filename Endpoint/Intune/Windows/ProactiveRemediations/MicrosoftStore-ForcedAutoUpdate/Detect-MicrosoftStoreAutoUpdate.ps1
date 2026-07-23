<#	
.NOTES
	Name: Detect-Microsoft_Store_Auto_Update.ps1
	Author: Joel Cottrell
	Copyright: GPLv3
	Tags: intune endpoint MEM microsoft store

.LICENSEURI
https://github.com/bigjoestretch/public/blob/main/LICENSE

.PROJECTURI
https://github.com/bigjoestretch/public/tree/main/Intune/Windows/Proactive%20Remediations/Microsoft%20Store%20Forced%20Auto%20Update

.ICONURI

.EXTERNALMODULEDEPENDENCIES

.REQUIREDSCRIPTS 

.EXTERNALSCRIPTDEPENDENCIES

.RELEASENOTES
v1.0 - 24/10/15 - Initial release of this script.
	
.SYNOPSIS
Powershell script to force app updates in the Microsoft Store.

.DESCRIPTION
This script forces app updates in the Microsoft Store using a proactive remediation script.

Per: https://memv.ennbee.uk/posts/updating-windows-store-apps/
    
.EXAMPLE
.\Remediate-Microsoft_Store_Auto_Update.ps1

#>

# Detect whether the result of the LastScanError (for the Microsoft Store app) is a zero or not, and if it’s not a zero throw an Exit 1 to allow a remediation to run.

try {
    $wmiObj = Get-CimInstance -Namespace "Root\cimv2\mdm\dmmap" -ClassName "MDM_EnterpriseModernAppManagement_AppManagement01"
    if ($wmiObj.LastScanError -ne '0') {
        Write-Output "Windows Store Apps not updated."
        Exit 1
    }
    else {
        Write-Output "Windows Store Apps updated."
        Exit 0
    }
}
catch {
    Write-Output "Unable to query Store App Update status."
    Exit 2000
}
