<#
.NOTES
    Filename: Detect-Zscaler.ps1
    Version: 1.0
    Author: Joel Cottrell
    Modified by: Joel Cottrell
    Requires: PowerShell v5 
    Copyright: GPLv3
	Tags: intune endpoint MEM zscaler
 
.LICENSEURI
https://github.com/bigjoestretch/public/blob/main/LICENSE

.PROJECTURI
https://github.com/bigjoestretch/public/blob/main/Intune/Proactive%20Remediations/Uninstall%20App/Zscaler

.ICONURI

.EXTERNALMODULEDEPENDENCIES

.REQUIREDSCRIPTS 

.EXTERNALSCRIPTDEPENDENCIES

.RELEASENOTES
v1.0 - 24/08/15 - Initial release of this script.

.SYNOPSIS
    This script package will attempt to detect the Zscaler application on the targeted devices.
    This script is used as detection script with Proactive Remediations in the Microsoft Intune admin center.
.DESCRIPTION
    Detect the Zscaler application.

.EXAMPLE
Detect-Zscaler.ps1

#>

# Detection script
$appdetails = (Get-ItemProperty Registry::HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*) | Where-Object {$_.DisplayName -eq "Zscaler"}
try {
    if ($appdetails.DisplayName -eq "Zscaler"){
    Write-Output "Zscaler is installed and will now be removed"
    Exit 1
    }

    else {
    Write-Output "Zscaler is not installed. No action required"
    Exit 0
}
}

 catch{
    $errMsg = $_.exeption.essage
    Write-Output $errMsg
 }
