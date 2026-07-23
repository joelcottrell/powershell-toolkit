<#	
.NOTES
	Name: uninstall-snagit-2024.ps1
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
Uninstall script used to uninstall the SnagIT 2024 application from a Windows device.

.DESCRIPTION
This script is used to uninstall the SnagIT 2024 application from a Windows device.

.EXAMPLE
.\uninstall-snagit-2024.ps1

#>

#Silently uninstall SnagIT 2024

#msiexec /x (Get-Package 'Snagit 2024*').FastPackageReference /qn
.\UninstallerTool_1_2_0.exe -product snagit -remove 24
