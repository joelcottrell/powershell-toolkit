<#	
.NOTES
	Name: Remediate-Microsoft_Store_Auto_Update.ps1
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

# Kick off an update in the Microsoft Store app to update all apps.

Try {
    Get-CimInstance -Namespace "Root\cimv2\mdm\dmmap" -ClassName "MDM_EnterpriseModernAppManagement_AppManagement01" | Invoke-CimMethod -MethodName UpdateScanMethod
    Write-Output "Windows Store Apps updated."
    Exit 0
}
Catch {
    Write-Output "Windows Store Apps not updated."
    Exit 2000
}
