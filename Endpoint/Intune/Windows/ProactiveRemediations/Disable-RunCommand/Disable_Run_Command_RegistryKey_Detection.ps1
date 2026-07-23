<#	
.NOTES
	Name: Disable_Run_Command_RegistryKey_Detection.ps1
	Author: Joel Cottrell
	Copyright: GPLv3
	Tags: intune endpoint MEM proactive remediation disable run

.LICENSEURI
https://github.com/bigjoestretch/public/blob/main/LICENSE

.PROJECTURI
https://github.com/bigjoestretch/public/blob/main/Intune/Windows/Proactive%20Remediations/Disable%20Run%20Command

.ICONURI

.EXTERNALMODULEDEPENDENCIES

.REQUIREDSCRIPTS 

.EXTERNALSCRIPTDEPENDENCIES

.RELEASENOTES
v1.0 - 25/03/18 - Initial release of this script.
	
.SYNOPSIS
Microsoft Intune Proactive Remediation script to disable the run command.

.DESCRIPTION
This Microsoft Intune Proactive Remediation script will check the Windows registry for a key that disables the run command so users are unable to use it.

    
.EXAMPLE
.\Disable_Run_Command_RegistryKey_Detection.ps1

#>

#Disable the Run Command in Windows

#Per: https://www.majorgeeks.com/content/page/disable_run_command.html
#Per: https://mikemdm.de/2023/06/04/create-or-set-registry-keys-in-intune-using-proactive-remediations/

#Set variable

$regkey="HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer"
$name="NoRun"
$value=1

#"Disable Run Command" Registry Detection Template

If (!(Test-Path $regkey))
{
Write-Output 'Disable Run Command RegKey not available - Remediate'
Exit 1
}


$check=(Get-ItemProperty -path $regkey -name $name -ErrorAction SilentlyContinue).$name
if ($check -eq $value){
write-output 'Disable Run Command RegKey is set - No remediation required'
Exit 0
}

else {
write-output 'Disable Run Command RegKey is not ok, does not exist or could not be read - Will Remediate now'
Exit 1
}
