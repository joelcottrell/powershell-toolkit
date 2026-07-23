<#	
.NOTES
	Name: Install-DattoRMMAgent.ps1
	Author: Joel Cottrell
	Copyright: GPLv3
	Tags: intune endpoint MEM datto rmm

.LICENSEURI
https://github.com/joelcottrell/powershell-toolkit/blob/main/LICENSE

.PROJECTURI
https://github.com/joelcottrell/powershell-toolkit/tree/main/Endpoint/Intune/Windows/Win32Apps/Datto-RMM/Windows

.ICONURI

.EXTERNALMODULEDEPENDENCIES

.REQUIREDSCRIPTS 

.EXTERNALSCRIPTDEPENDENCIES

.RELEASENOTES
v1.0 - 24/10/09 - Initial release of this script.
	
.SYNOPSIS
Powershell script to install the Datto RMM agent onto a Windows device

.DESCRIPTION
This script deploys the Kaseya Datto RMM agent to Windows devices, pre-configured with your Datto RMM
platform name and the SiteID of the target site.

Both values are specific to your own tenant and must be supplied before use:

    Platform - the subdomain of your Datto RMM instance. Visible in the portal URL,
               for example 'https://<platform>.rmm.datto.com'.
    SiteID   - the GUID of the target site. Found in the portal under
               Sites > <your site> > Settings.

Treat the SiteID as a secret. It is the only token required to download an agent
installer bound to your site, so do not commit a live value to source control.

.PARAMETER Platform
The Datto RMM platform subdomain for your tenant.

.PARAMETER SiteID
The GUID of the Datto RMM site the device should enroll into.

.EXAMPLE
.\Install-DattoRMMAgent.ps1 -Platform "contoso" -SiteID "00000000-0000-0000-0000-000000000000"

#>

param(
    [Parameter(Mandatory = $true)]
    [string]$Platform,

    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')]
    [string]$SiteID
)

<# 
Datto RMM Agent deploy by MS Azure Intune 
Designed and written by Jon North, Datto, March 2020 
Download the Agent installer, run it, wait for it to finish, delete it 
#> 
# First check if Agent is installed and instantly exit if so
If (Get-Service CagService -ErrorAction SilentlyContinue) {Write-Output "Datto RMM Agent already installed on this device" ; exit} 
# Download the Agent
$AgentURL="https://$Platform.centrastage.net/csm/profile/downloadAgent/$SiteID" 
$DownloadStart=Get-Date 
Write-Output "Starting Agent download at $(Get-Date -Format HH:mm) from $AgentURL"
try {[Net.ServicePointManager]::SecurityProtocol=[Enum]::ToObject([Net.SecurityProtocolType],3072)}
catch {Write-Output "Cannot download Agent due to invalid security protocol. The`r`nfollowing security protocols are installed and available:`r`n$([enum]::GetNames([Net.SecurityProtocolType]))`r`nAgent download requires at least TLS 1.2 to succeed.`r`nPlease install TLS 1.2 and rerun the script." ; exit 1}
try {(New-Object System.Net.WebClient).DownloadFile($AgentURL, "$env:TEMP\DRMMSetup.exe")} 
catch {$host.ui.WriteErrorLine("Agent installer download failed. Exit message:`r`n$_") ; exit 1} 
Write-Output "Agent download completed in $((Get-Date).Subtract($DownloadStart).Seconds) seconds`r`n`r`n" 
# Install the Agent
$InstallStart=Get-Date 
Write-Output "Starting Agent install to target site at $(Get-Date -Format HH:mm)..." 
& "$env:TEMP\DRMMSetup.exe" | Out-Null 
Write-Output "Agent install completed at $(Get-Date -Format HH:mm) in $((Get-Date).Subtract($InstallStart).Seconds) seconds."
Remove-Item "$env:TEMP\DRMMSetup.exe" -Force
Exit
