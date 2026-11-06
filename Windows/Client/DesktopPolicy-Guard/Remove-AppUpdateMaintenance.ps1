<#
.SYNOPSIS
    Removes the App Update Maintenance scheduled task.

.DESCRIPTION
    Stops and unregisters the App Update Maintenance task. Optionally removes
    the installed maintenance script. It does not remove WinGet pins because
    those may have been created or may be required outside this project.

.PARAMETER InstallDirectory
    DesktopPolicy-Guard installation directory.

.PARAMETER TaskPath
    Task Scheduler folder path.

.PARAMETER TaskName
    Scheduled task name.

.PARAMETER RemoveInstalledScript
    Removes the installed Start-AppUpdateMaintenance.ps1 file.

.EXAMPLE
    .\Remove-AppUpdateMaintenance.ps1

.NOTES
    File Name  : Remove-AppUpdateMaintenance.ps1
    Author     : Joel Cottrell
    Version    : 1.0.0
    Updated    : 2026-11-05
    Requires   : PowerShell 7 or later; local administrator

    Repository : https://github.com/joelcottrell/powershell-toolkit
#>

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
param(
    [Parameter()]
    [string]$InstallDirectory = 'C:\ProgramData\DesktopPolicy-Guard',

    [Parameter()]
    [string]$TaskPath = '\DesktopPolicy-Guard\',

    [Parameter()]
    [string]$TaskName = 'App Update Maintenance',

    [Parameter()]
    [switch]$RemoveInstalledScript
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$task = Get-ScheduledTask -TaskPath $TaskPath -TaskName $TaskName -ErrorAction SilentlyContinue

if ($null -ne $task -and $PSCmdlet.ShouldProcess("$TaskPath$TaskName", 'Stop and unregister scheduled task')) {
    Stop-ScheduledTask -TaskPath $TaskPath -TaskName $TaskName -ErrorAction SilentlyContinue
    Unregister-ScheduledTask -TaskPath $TaskPath -TaskName $TaskName -Confirm:$false
    Write-Host "Removed task: $TaskPath$TaskName" -ForegroundColor Green
}

if ($RemoveInstalledScript) {
    $installedScript = Join-Path -Path $InstallDirectory -ChildPath 'Start-AppUpdateMaintenance.ps1'

    if ((Test-Path -LiteralPath $installedScript -PathType Leaf) -and $PSCmdlet.ShouldProcess($installedScript, 'Remove installed maintenance script')) {
        Remove-Item -LiteralPath $installedScript -Force
        Write-Host "Removed: $installedScript" -ForegroundColor Green
    }
}
