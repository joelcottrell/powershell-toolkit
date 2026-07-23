<#	
.NOTES
	Name: Install-ZuluJRE.ps1
	Author: Joel Cottrell
	Copyright: GPLv3
	Tags: intune endpoint MEM azul zulu jre

.LICENSEURI
https://github.com/joelcottrell/powershell-toolkit/blob/main/LICENSE

.PROJECTURI
https://github.com/joelcottrell/powershell-toolkit/tree/main/Endpoint/Intune/Windows/Win32Apps/Azul-Zulu-OpenJRE

.ICONURI

.EXTERNALMODULEDEPENDENCIES

.REQUIREDSCRIPTS 

.EXTERNALSCRIPTDEPENDENCIES

.RELEASENOTES
v1.0 - 24/09/25 - Initial release of this script.
	
.SYNOPSIS
Install script used to install the Azul Zulu Build of OpenJDK on Windows.

.DESCRIPTION
This script is used to install the Azul Zulu Build of OpenJDK onto a Windows device.

Inspiration in creating this was provide by steps found in this link:

https://www.azul.com/downloads/?package=jre#zulu
https://docs.azul.com/core/install/windows
    
.EXAMPLE
./Install-ZuluJRE.ps1

#>

#Silently install Azul Zulu JRE version 21.0.4

msiexec /i zulu21.36.17-ca-jre21.0.4-win_x64.msi ADDLOCAL=ZuluInstallation,FeatureJavaHome INSTALLDIR="c:\java\jdk21" /qn
