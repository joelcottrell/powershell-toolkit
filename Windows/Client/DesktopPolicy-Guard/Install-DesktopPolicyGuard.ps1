<#
.SYNOPSIS
    Installs Desktop Policy Guard service and optional WinGet maintenance.

.DESCRIPTION
    Provides a single entry point for deploying the complete DesktopPolicy-Guard
    project.

    The script installs or refreshes the Windows service first. It then installs
    the short-lived WinGet application maintenance scheduled task.

    The service runs as LocalSystem. WinGet maintenance runs in the current
    administrator's user context because winget.exe is not supported under
    LocalSystem.

.PARAMETER InstallDirectory
    Installation directory used by both components.

.PARAMETER ServiceId
    Internal Windows service ID.

.PARAMETER ServiceName
    Windows service display name.

.PARAMETER WinSWSourcePath
    Optional local WinSW-x64.exe path.

.PARAMETER TaskPath
    Task Scheduler folder for App Update Maintenance.

.PARAMETER TaskName
    App Update Maintenance task name.

.PARAMETER DailyAt
    Daily App Update Maintenance start time in HH:mm format.

.PARAMETER AppUpdateMode
    WinGet maintenance mode: All or AllowList.

.PARAMETER EnableAppUpdates
    Enables App Update Maintenance in the installed configuration.

.PARAMETER StartAppUpdatesNow
    Starts App Update Maintenance immediately after installation.

.EXAMPLE
    .\Install-DesktopPolicyGuard.ps1 -EnableAppUpdates

.EXAMPLE
    .\Install-DesktopPolicyGuard.ps1 `
        -InstallDirectory 'C:\ProgramData\IT-Automation\DesktopPolicyGuard' `
        -ServiceId 'ITDesktopPolicyGuard' `
        -ServiceName 'IT Desktop Policy Guard' `
        -TaskPath '\IT-Automation\' `
        -EnableAppUpdates `
        -StartAppUpdatesNow

.NOTES
    File Name  : Install-DesktopPolicyGuard.ps1
    Author     : Joel Cottrell
    Version    : 1.0.0
    Updated    : 2026-11-06
    Requires   : PowerShell 7 or later; local administrator; WinGet

    Repository : https://github.com/joelcottrell/powershell-toolkit
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter()]
    [string]$InstallDirectory = 'C:\ProgramData\DesktopPolicy-Guard',

    [Parameter()]
    [ValidatePattern('^[A-Za-z0-9_.-]+$')]
    [string]$ServiceId = 'DesktopPolicyGuard',

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$ServiceName = 'Desktop Policy Guard',

    [Parameter()]
    [string]$WinSWSourcePath,

    [Parameter()]
    [string]$TaskPath = '\DesktopPolicy-Guard\',

    [Parameter()]
    [string]$TaskName = 'App Update Maintenance',

    [Parameter()]
    [ValidatePattern('^(?:[01]\d|2[0-3]):[0-5]\d$')]
    [string]$DailyAt = '03:00',

    [Parameter()]
    [ValidateSet('All', 'AllowList')]
    [string]$AppUpdateMode = 'All',

    [Parameter()]
    [switch]$EnableAppUpdates,

    [Parameter()]
    [switch]$StartAppUpdatesNow
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Test-IsAdministrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)

    return $principal.IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator
    )
}

if ($PSVersionTable.PSVersion.Major -lt 7) {
    throw 'Run the complete installer from PowerShell 7 or later.'
}

if (-not (Test-IsAdministrator)) {
    throw 'Run the complete installer from an elevated PowerShell 7 session.'
}

$serviceInstaller = Join-Path -Path $PSScriptRoot -ChildPath 'Install-DesktopPolicyGuardService.ps1'
$appUpdateInstaller = Join-Path -Path $PSScriptRoot -ChildPath 'Install-AppUpdateMaintenance.ps1'

foreach ($requiredScript in @($serviceInstaller, $appUpdateInstaller)) {
    if (-not (Test-Path -LiteralPath $requiredScript -PathType Leaf)) {
        throw "Required installer not found: $requiredScript"
    }
}

Write-Host ''
Write-Host 'DesktopPolicy-Guard Complete Installation' -ForegroundColor Cyan
Write-Host '-----------------------------------------' -ForegroundColor Cyan
Write-Host ("Install Directory : {0}" -f $InstallDirectory)
Write-Host ("Service ID        : {0}" -f $ServiceId)
Write-Host ("Service Name      : {0}" -f $ServiceName)
Write-Host ("Task Path         : {0}" -f $TaskPath)
Write-Host ("Task Name         : {0}" -f $TaskName)
Write-Host ("Daily At          : {0}" -f $DailyAt)
Write-Host ("App Update Mode   : {0}" -f $AppUpdateMode)
Write-Host ("App Updates       : {0}" -f $(if ($EnableAppUpdates) { 'Enabled' } else { 'Installed but disabled' }))
Write-Host ''

if (-not $PSCmdlet.ShouldProcess($InstallDirectory, 'Install Desktop Policy Guard service and App Update Maintenance')) {
    return
}

$serviceParameters = @{
    InstallDirectory = $InstallDirectory
    ServiceId        = $ServiceId
    ServiceName      = $ServiceName
    Confirm          = $false
}

if (-not [string]::IsNullOrWhiteSpace($WinSWSourcePath)) {
    $serviceParameters.WinSWSourcePath = $WinSWSourcePath
}

Write-Host '[1/2] Installing Desktop Policy Guard service...' -ForegroundColor Cyan
& $serviceInstaller @serviceParameters

if ($LASTEXITCODE -ne 0) {
    throw "Desktop Policy Guard service installer exited with code $LASTEXITCODE."
}

$appUpdateParameters = @{
    InstallDirectory = $InstallDirectory
    TaskPath         = $TaskPath
    TaskName         = $TaskName
    DailyAt          = $DailyAt
    Mode             = $AppUpdateMode
    Confirm          = $false
}

if ($EnableAppUpdates) {
    $appUpdateParameters.Enable = $true
}

if ($StartAppUpdatesNow) {
    $appUpdateParameters.StartNow = $true
}

Write-Host ''
Write-Host '[2/2] Installing App Update Maintenance...' -ForegroundColor Cyan
& $appUpdateInstaller @appUpdateParameters

if ($LASTEXITCODE -ne 0) {
    throw "App Update Maintenance installer exited with code $LASTEXITCODE."
}

Write-Host ''
Write-Host 'DesktopPolicy-Guard installation completed.' -ForegroundColor Green
Write-Host ''
Write-Host 'Verify service:' -ForegroundColor Cyan
Write-Host ("  Get-Service '{0}'" -f $ServiceId)
Write-Host ''
Write-Host 'Verify maintenance task:' -ForegroundColor Cyan
Write-Host ("  Get-ScheduledTask -TaskPath '{0}' -TaskName '{1}'" -f $TaskPath, $TaskName)
