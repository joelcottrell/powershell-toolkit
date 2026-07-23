<#	
.NOTES
	Name: Uninstall-ZuluJRE.ps1
	Author: Joel Cottrell
	Copyright: GPLv3
	Tags: intune endpoint MEM azul zulu jre

.LICENSEURI
https://github.com/bigjoestretch/powershell-toolkit/blob/main/LICENSE

.PROJECTURI
https://github.com/bigjoestretch/powershell-toolkit/tree/main/Endpoint/Intune/Windows/Win32Apps/Azul-Zulu-OpenJRE

.ICONURI

.EXTERNALMODULEDEPENDENCIES

.REQUIREDSCRIPTS 

.EXTERNALSCRIPTDEPENDENCIES

.RELEASENOTES
v1.0 - 24/09/25 - Initial release of this script.
	
.SYNOPSIS
Uninstall script used to uninstall the Azul Zulu Build of OpenJDK on Windows.

.DESCRIPTION
This script is used to uninstall the Azul Zulu Build of OpenJDK from a Windows device.

Inspiration in creating this was provide by steps found in this link:

https://docs.azul.com/core/uninstall/windows
    
.EXAMPLE
./Uninstall-ZuluJRE.ps1

#>

#Silently uninstall Azul Zulu JRE

msiexec /x (Get-Package 'Azul Zulu JRE*').FastPackageReference /qn
