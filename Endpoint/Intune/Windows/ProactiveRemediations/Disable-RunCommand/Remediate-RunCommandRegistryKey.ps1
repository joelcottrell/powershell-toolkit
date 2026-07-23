<#	
.NOTES
	Name: Remediate-RunCommandRegistryKey.ps1
	Author: Joel Cottrell
	Copyright: GPLv3
	Tags: intune endpoint MEM proactive remediation disable run

.LICENSEURI
https://github.com/joelcottrell/powershell-toolkit/blob/main/LICENSE

.PROJECTURI
https://github.com/joelcottrell/powershell-toolkit/tree/main/Endpoint/Intune/Windows/ProactiveRemediations/Disable-RunCommand

.ICONURI

.EXTERNALMODULEDEPENDENCIES

.REQUIREDSCRIPTS 

.EXTERNALSCRIPTDEPENDENCIES

.RELEASENOTES
v1.0 - 25/03/18 - Initial release of this script.
	
.SYNOPSIS
Microsoft Intune Proactive Remediation script to disable the run command.

.DESCRIPTION
This Microsoft Intune Proactive Remediation script will create a Windows registry key that disables the run command so users are unable to use it.

    
.EXAMPLE
.\Remediate-RunCommandRegistryKey.ps1

#>

#Disable the Run Command in Windows

#Per: https://www.majorgeeks.com/content/page/disable_run_command.html
#Per: https://mikemdm.de/2023/06/04/create-or-set-registry-keys-in-intune-using-proactive-remediations/

#Set Variable

$regkey="HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer"
$name="NoRun"
$value=1

#"Disable Run Command" Registry Detection Template

If (!(Test-Path $regkey))
{
New-Item -Path $regkey -ErrorAction stop
}

if (!(Get-ItemProperty -Path $regkey -Name $name -ErrorAction SilentlyContinue))
{
New-ItemProperty -Path $regkey -Name $name -Value $value -PropertyType DWORD -ErrorAction stop
write-output "Disable Run Command RegKey Remediation Complete"
exit 0
}

set-ItemProperty -Path $regkey -Name $name -Value $value -ErrorAction stop
write-output "Disable Run Command RegKey Remediation Complete"
exit 0
