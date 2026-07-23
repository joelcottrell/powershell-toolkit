<#  
.NOTES  
    Name: Remediate-WinVerOEMInfo.ps1  
    Author: Niklas Rast
    Modified by: Joel Cottrell  
    Requires: PowerShell v5 
    Copyright: GPLv3
	Tags: intune endpoint MEM winver oem
 
.LICENSEURI
https://github.com/joelcottrell/powershell-toolkit/blob/main/LICENSE

.PROJECTURI
https://github.com/joelcottrell/powershell-toolkit/tree/main/Endpoint/Intune/Windows/ProactiveRemediations/Change-WinVerOEMInfo

.ICONURI

.EXTERNALMODULEDEPENDENCIES

.REQUIREDSCRIPTS 

.EXTERNALSCRIPTDEPENDENCIES

.RELEASENOTES
v1.0 - 23/12/11 - Initial release of this script.  

.SYNOPSIS  
    Change the WinVer and OEM Info on a Windows device.
.DESCRIPTION  
    This Proactive Remediation remediation script updates the WinVer and OEM Info
    entries in the registry with values you specify below.

    Inspiration in creating this was provide by steps found in this link:
    
    https://niklasrast.com/2023/10/05/elevate-your-corporate-branding-on-managed-windows-devices-with-microsoft-intune-remediations/

.EXAMPLE
Remediate-WinVerOEMInfo.ps1

#>

# Customize the following registry entries with your own info.
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

    IF (!(Test-Path ($Brand.RegKeyPath))) {
        Write-Host ($Brand.RegKeyPath) " does not exist. Will be created."
        New-Item -Path $RegKeyPath -Force | Out-Null
    }
    IF (!(Get-Item -Path $($Brand.Key))) {
        Write Host $($Brand.Key) " does not exist. Will be created."
        New-ItemProperty -Path $($Brand.RegKeyPath) -Name $($Brand.Key) -Value $($Brand.Value) -PropertyType STRING -Force
    }
    
    $ExistingValue = (Get-Item -Path $($Brand.RegKeyPath)).GetValue($($Brand.Key))
    if ($ExistingValue -ne $($Brand.Value)) {
        Write-Host $($Brand.Key) " not correct value. Will be set."
        Set-ItemProperty -Path $($Brand.RegKeyPath) -Name $($Brand.Key) -Value $($Brand.Value) -Force
    }
    else {
        Write-Host $($Brand.Key) " is correct"
    }
}

Exit 0
