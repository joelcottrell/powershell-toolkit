<#  
.NOTES  
    Name: Detect-WinVerOEMInfo.ps1  
    Author: Niklas Rast
    Modified by: Joel Cottrell  
    Requires: PowerShell v5 
    Copyright: GPLv3
	Tags: intune endpoint MEM winver oem
 
.LICENSEURI
https://github.com/bigjoestretch/powershell-toolkit/blob/main/LICENSE

.PROJECTURI
https://github.com/bigjoestretch/powershell-toolkit/tree/main/Endpoint/Intune/Windows/ProactiveRemediations/Change-WinVerOEMInfo

.ICONURI

.EXTERNALMODULEDEPENDENCIES

.REQUIREDSCRIPTS 

.EXTERNALSCRIPTDEPENDENCIES

.RELEASENOTES
v1.0 - 23/12/11 - Initial release of this script.  

.SYNOPSIS  
    Change the WinVer and OEM Info on a Windows device.

.DESCRIPTION  
    This Proactive Remediation detection script checks to see whether the WinVer and OEM Info
    entries in the registry contain values.

    Inspiration in creating this was provide by steps found in this link:
    
    https://niklasrast.com/2023/10/05/elevate-your-corporate-branding-on-managed-windows-devices-with-microsoft-intune-remediations/

.EXAMPLE
Detect-WinVerOEMInfo.ps1

#>

$BrandingContent = @"
RegKeyPath,Key,Value
"HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\OEMInformation","SupportURL","https://support.example.com/"
"HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\OEMInformation","Manufacturer","Lenovo"
"HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\OEMInformation","SupportHours","Standard: 8AM - 5PM EST"
"HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\OEMInformation","SupportPhone","(555) 555-0100"
"HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion","RegisteredOwner","Contoso"
"HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion","RegisteredOrganization","Contoso"
"@

$Branding = $BrandingContent | ConvertFrom-Csv -delimiter ","

foreach ($Brand in $Branding) {
    $ExistingValue = (Get-Item -Path $($Brand.RegKeyPath)).GetValue($($Brand.Key))
    if ($ExistingValue -ne $($Brand.Value)) {
      Write-Host $($Brand.Key) "Not Equal"
      Exit 1
      Exit #Remediation 
    }
    else {
#      Write-Host $($Brand.Key) "Equal"
    }
}
Exit 0
