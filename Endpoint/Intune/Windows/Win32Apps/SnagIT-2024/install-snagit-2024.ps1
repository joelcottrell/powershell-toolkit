<#	
.NOTES
	Name: install-snagit-2024.ps1 
	Author: Joel Cottrell
  	Copyright: GPLv3
	Tags: intune endpoint MEM snagit 2024

.LICENSEURI
https://github.com/bigjoestretch/public/blob/main/LICENSE

.PROJECTURI
https://github.com/bigjoestretch/public/blob/main/Intune/Windows/Win32Apps/SnagIT%202024


.ICONURI

.EXTERNALMODULEDEPENDENCIES

.REQUIREDSCRIPTS 

.EXTERNALSCRIPTDEPENDENCIES

.RELEASENOTES
v1.0 - 24/09/26 - Initial release of this script.
	
.SYNOPSIS
Script to install SnagIT 2024 using a .mst MSI transform file

.DESCRIPTION
This script installs SnagIT 2024 using a .mst MSI transform file via Microsoft Intune.

Inspiration in creating this was provide by steps found in this link:

https://assets.techsmith.com/Docs/Snagit-2024-MSI-Installation-Guide.pdf

.EXAMPLE
.\install-snagit-2024.ps1

#>

# Install SnagIT 2024 silently without a restart
#msiexec.exe /I "%~dp0snagit.msi" TRANSFORMS="%~dp0snagit.mst" /quiet /norestart
msiexec /i "snagit.msi" TRANSFORMS="snagit.mst" /qn /norestart
