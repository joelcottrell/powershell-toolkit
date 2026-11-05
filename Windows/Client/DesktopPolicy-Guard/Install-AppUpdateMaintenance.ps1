<#
.SYNOPSIS
    Installs scheduled WinGet application update maintenance.

.DESCRIPTION
    Copies Start-AppUpdateMaintenance.ps1 into the DesktopPolicy-Guard install
    directory, adds a safe AppUpdates section to an existing config.json when
    needed, and creates a daily scheduled task under the selected Task Scheduler
    folder.

    The task runs in the current administrator's interactive user context with
    highest privileges and exits after each maintenance run. It does not create
    a persistent PowerShell process.

.PARAMETER InstallDirectory
    DesktopPolicy-Guard installation directory.

.PARAMETER TaskPath
    Task Scheduler folder path.

.PARAMETER TaskName
    Scheduled task name.

.PARAMETER DailyAt
    Daily task start time in HH:mm format.

.PARAMETER Enable
    Enables AppUpdates in the installed config.json.

.PARAMETER Mode
    App update mode: All or AllowList.

.PARAMETER StartNow
    Starts the task after registration.

.EXAMPLE
    .\Install-AppUpdateMaintenance.ps1 -Enable -Mode All -StartNow

.EXAMPLE
    .\Install-AppUpdateMaintenance.ps1 -TaskPath '\BCH-IT\' -Enable -StartNow

.NOTES
    File Name  : Install-AppUpdateMaintenance.ps1
    Author     : Joel Cottrell
    Version    : 1.0.0
    Updated    : 2026-11-05
    Requires   : PowerShell 7 or later; local administrator; WinGet

    Repository : https://github.com/joelcottrell/powershell-toolkit
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter()]
    [string]$InstallDirectory = 'C:\ProgramData\DesktopPolicy-Guard',

    [Parameter()]
    [string]$TaskPath = '\DesktopPolicy-Guard\',

    [Parameter()]
    [string]$TaskName = 'App Update Maintenance',

    [Parameter()]
    [ValidatePattern('^(?:[01]\d|2[0-3]):[0-5]\d$')]
    [string]$DailyAt = '03:00',

    [Parameter()]
    [switch]$Enable,

    [Parameter()]
    [ValidateSet('All', 'AllowList')]
    [string]$Mode = 'All',

    [Parameter()]
    [switch]$StartNow
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Test-IsAdministrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Ensure-TaskSchedulerFolder {
    param(
        [Parameter(Mandatory)]
        [string]$FolderPath
    )

    $normalized = '\' + $FolderPath.Trim('\')

    if ($normalized -eq '\') {
        return
    }

    $folderName = $normalized.Trim('\')

    if ($folderName.Contains('\')) {
        throw 'Only a single Task Scheduler folder level is supported.'
    }

    $service = New-Object -ComObject 'Schedule.Service'
    $service.Connect()

    try {
        $null = $service.GetFolder($normalized)
    }
    catch {
        $root = $service.GetFolder('\')
        $null = $root.CreateFolder($folderName, $null)
    }
}

if ($PSVersionTable.PSVersion.Major -lt 7) {
    throw 'Run this installer from PowerShell 7 or later.'
}

if (-not (Test-IsAdministrator)) {
    throw 'Run this installer from an elevated PowerShell session.'
}

$winget = Get-Command winget.exe -ErrorAction SilentlyContinue

if ($null -eq $winget) {
    throw 'winget.exe was not found for the current user.'
}

$pwsh = (Get-Process -Id $PID).Path

if ([string]::IsNullOrWhiteSpace($pwsh) -or -not (Test-Path -LiteralPath $pwsh)) {
    throw 'Unable to determine the current PowerShell 7 executable path.'
}

$sourceScript = Join-Path -Path $PSScriptRoot -ChildPath 'Start-AppUpdateMaintenance.ps1'
$installedScript = Join-Path -Path $InstallDirectory -ChildPath 'Start-AppUpdateMaintenance.ps1'
$installedConfig = Join-Path -Path $InstallDirectory -ChildPath 'config.json'
$exampleConfig = Join-Path -Path $PSScriptRoot -ChildPath 'Config\config.example.json'

foreach ($required in @($sourceScript, $exampleConfig)) {
    if (-not (Test-Path -LiteralPath $required -PathType Leaf)) {
        throw "Required file not found: $required"
    }
}

if (-not (Test-Path -LiteralPath $installedConfig -PathType Leaf)) {
    throw "Installed DesktopPolicy-Guard configuration not found: $installedConfig"
}

if (-not $PSCmdlet.ShouldProcess($TaskName, 'Install App Update Maintenance scheduled task')) {
    return
}

Copy-Item -LiteralPath $sourceScript -Destination $installedScript -Force
Unblock-File -LiteralPath $installedScript -ErrorAction SilentlyContinue

$installed = Get-Content -LiteralPath $installedConfig -Raw | ConvertFrom-Json
$example = Get-Content -LiteralPath $exampleConfig -Raw | ConvertFrom-Json

if ($null -eq $installed.AppUpdates) {
    $installed | Add-Member -MemberType NoteProperty -Name AppUpdates -Value $example.AppUpdates
}

$installed.AppUpdates.Mode = $Mode

if ($Enable) {
    $installed.AppUpdates.Enabled = $true
}

$installed | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $installedConfig -Encoding UTF8

Ensure-TaskSchedulerFolder -FolderPath $TaskPath

$existing = Get-ScheduledTask -TaskPath $TaskPath -TaskName $TaskName -ErrorAction SilentlyContinue

if ($null -ne $existing) {
    Stop-ScheduledTask -TaskPath $TaskPath -TaskName $TaskName -ErrorAction SilentlyContinue
    Unregister-ScheduledTask -TaskPath $TaskPath -TaskName $TaskName -Confirm:$false
}

$taskArguments = '-NoLogo -NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File "{0}" -ConfigPath "{1}"' -f $installedScript, $installedConfig

$action = New-ScheduledTaskAction -Execute $pwsh -Argument $taskArguments -WorkingDirectory $InstallDirectory

$time = [datetime]::ParseExact($DailyAt, 'HH:mm', $null)
$trigger = New-ScheduledTaskTrigger -Daily -At $time

$userId = [Security.Principal.WindowsIdentity]::GetCurrent().Name
$principal = New-ScheduledTaskPrincipal -UserId $userId -LogonType Interactive -RunLevel Highest

$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -ExecutionTimeLimit (New-TimeSpan -Hours 4) -MultipleInstances IgnoreNew

$definition = New-ScheduledTask -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Description 'Runs a short-lived hidden WinGet application update maintenance pass.'

Register-ScheduledTask -TaskPath $TaskPath -TaskName $TaskName -InputObject $definition -Force | Out-Null

Write-Host "Installed task: $TaskPath$TaskName" -ForegroundColor Green
Write-Host "Run as        : $userId"
Write-Host "Daily at      : $DailyAt"
Write-Host "Mode          : $Mode"
Write-Host "Enabled       : $($installed.AppUpdates.Enabled)"

if ($StartNow) {
    Start-ScheduledTask -TaskPath $TaskPath -TaskName $TaskName
    Write-Host 'Started App Update Maintenance.' -ForegroundColor Green
}
