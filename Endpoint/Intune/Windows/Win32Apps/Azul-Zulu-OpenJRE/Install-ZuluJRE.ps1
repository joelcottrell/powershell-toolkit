<#	
.NOTES
	Name: install-zulu-jre.ps1
	Author: Joel Cottrell
	Copyright: GPLv3
	Tags: intune endpoint MEM azul zulu jre

.LICENSEURI
https://github.com/bigjoestretch/public/blob/main/LICENSE

.PROJECTURI
https://github.com/bigjoestretch/public/blob/main/Intune/Windows/Win32Apps/Azul%20Zulu%20OpenJRE

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
./install-zulu-jre.ps1

#>

#Silently install Azul Zulu JRE version 21.0.4

msiexec /i zulu21.36.17-ca-jre21.0.4-win_x64.msi ADDLOCAL=ZuluInstallation,FeatureJavaHome INSTALLDIR="c:\java\jdk21" /qn
