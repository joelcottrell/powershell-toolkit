<#
.SYNOPSIS
    Audits or installs application updates through WinGet.

.DESCRIPTION
    Runs as a short-lived user-context maintenance workload. This script is
    intentionally separate from the LocalSystem Desktop Policy Guard service
    because winget.exe is not supported in LocalSystem context.

    All mode runs winget upgrade --all after ensuring configured exclusions are
    pinned so they are skipped. AllowList mode updates only package IDs listed
    in the configuration.

    -AuditOnly reports available updates without installing them.

.PARAMETER ConfigPath
    Path to the DesktopPolicy-Guard JSON configuration.

.PARAMETER AuditOnly
    Reports available updates without installing them.

.EXAMPLE
    .\Start-AppUpdateMaintenance.ps1 -AuditOnly

.NOTES
    File Name  : Start-AppUpdateMaintenance.ps1
    Author     : Joel Cottrell
    Version    : 1.0.0
    Updated    : 2026-11-05
    Requires   : PowerShell 7 or later; WinGet

    Repository : https://github.com/joelcottrell/powershell-toolkit
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string]$ConfigPath = (Join-Path -Path $PSScriptRoot -ChildPath 'config.json'),

    [Parameter()]
    [switch]$AuditOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$RunId = Get-Date -Format 'yyyyMMdd-HHmmss'
$LogRoot = Join-Path -Path $PSScriptRoot -ChildPath 'Logs\AppUpdateMaintenance'
$LogFile = Join-Path -Path $LogRoot -ChildPath "AppUpdateMaintenance-$RunId.log"
$ReportFile = Join-Path -Path $LogRoot -ChildPath "AppUpdateMaintenance-$RunId.json"

function Write-AppUpdateLog {
    param(
        [Parameter(Mandatory)]
        [ValidateSet('INFO', 'SUCCESS', 'WARNING', 'ERROR', 'AUDIT')]
        [string]$Level,

        [Parameter(Mandatory)]
        [string]$Message
    )

    if (-not (Test-Path -LiteralPath $LogRoot)) {
        New-Item -Path $LogRoot -ItemType Directory -Force | Out-Null
    }

    $entry = '{0} [{1}] [{2}] {3}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $env:COMPUTERNAME, $Level, $Message
    Add-Content -LiteralPath $LogFile -Value $entry -Encoding UTF8
}

function Get-WinGetPath {
    $command = Get-Command winget.exe -ErrorAction SilentlyContinue

    if ($null -ne $command) {
        return $command.Source
    }

    throw 'winget.exe was not found in the current user context.'
}

function Invoke-WinGet {
    param(
        [Parameter(Mandatory)]
        [string[]]$Arguments
    )

    $output = & $script:WinGetPath @Arguments 2>&1
    $exitCode = $LASTEXITCODE

    [pscustomobject]@{
        ExitCode = $exitCode
        Output   = @($output | ForEach-Object { [string]$_ })
    }
}

function Ensure-ExcludedPackagePin {
    param(
        [Parameter(Mandatory)]
        [string]$Id
    )

    $pinList = Invoke-WinGet -Arguments @(
        'pin', 'list',
        '--id', $Id,
        '--exact',
        '--accept-source-agreements',
        '--disable-interactivity'
    )

    $alreadyPinned = ($pinList.Output -join [Environment]::NewLine) -match [regex]::Escape($Id)

    if ($alreadyPinned) {
        Write-AppUpdateLog -Level 'INFO' -Message "Exclusion already pinned: $Id"
        return
    }

    if ($AuditOnly) {
        Write-AppUpdateLog -Level 'AUDIT' -Message "Would add WinGet exclusion pin: $Id"
        return
    }

    $pinAdd = Invoke-WinGet -Arguments @(
        'pin', 'add',
        '--id', $Id,
        '--exact',
        '--accept-source-agreements',
        '--disable-interactivity'
    )

    if ($pinAdd.ExitCode -ne 0) {
        throw "Unable to add WinGet pin for '$Id'. $($pinAdd.Output -join ' ')"
    }

    Write-AppUpdateLog -Level 'SUCCESS' -Message "Added WinGet exclusion pin: $Id"
}

if ($PSVersionTable.PSVersion.Major -lt 7) {
    throw 'App Update Maintenance requires PowerShell 7 or later.'
}

if (-not (Test-Path -LiteralPath $ConfigPath -PathType Leaf)) {
    throw "Configuration file not found: $ConfigPath"
}

$config = Get-Content -LiteralPath $ConfigPath -Raw | ConvertFrom-Json

if ($null -eq $config.AppUpdates) {
    throw 'The AppUpdates section is missing from config.json.'
}

$appConfig = $config.AppUpdates

if (-not [bool]$appConfig.Enabled -and -not $AuditOnly) {
    Write-Host 'App Update Maintenance is disabled in configuration.'
    exit 0
}

if (-not [bool]$appConfig.Enabled -and $AuditOnly) {
    Write-AppUpdateLog -Level 'AUDIT' -Message 'AppUpdates.Enabled is false; continuing because AuditOnly was requested.'
}

New-Item -Path $LogRoot -ItemType Directory -Force | Out-Null

$script:WinGetPath = Get-WinGetPath
$versionResult = Invoke-WinGet -Arguments @('--version')

if ($versionResult.ExitCode -ne 0) {
    throw "WinGet validation failed. $($versionResult.Output -join ' ')"
}

$mode = [string]$appConfig.Mode
$results = [System.Collections.Generic.List[object]]::new()
$failed = $false

Write-AppUpdateLog -Level 'INFO' -Message "Run started. Mode=$mode; AuditOnly=$([bool]$AuditOnly); WinGet=$($versionResult.Output -join ' ')."

foreach ($excludedId in @($appConfig.ExcludedPackages)) {
    if ([string]::IsNullOrWhiteSpace([string]$excludedId)) {
        continue
    }

    try {
        Ensure-ExcludedPackagePin -Id ([string]$excludedId)
    }
    catch {
        $failed = $true
        Write-AppUpdateLog -Level 'ERROR' -Message $_.Exception.Message
    }
}

if ($AuditOnly) {
    $auditArguments = @('upgrade', '--accept-source-agreements', '--disable-interactivity')

    if ([bool]$appConfig.IncludeUnknown) {
        $auditArguments += '--include-unknown'
    }

    $auditResult = Invoke-WinGet -Arguments $auditArguments

    foreach ($line in $auditResult.Output) {
        Write-AppUpdateLog -Level 'AUDIT' -Message $line
    }

    $results.Add([pscustomobject]@{
        Action   = 'Audit'
        ExitCode = $auditResult.ExitCode
        Output   = $auditResult.Output
    })
}
elseif ($mode -eq 'All') {
    $arguments = @(
        'upgrade',
        '--all',
        '--silent',
        '--accept-source-agreements',
        '--accept-package-agreements',
        '--disable-interactivity'
    )

    if ([bool]$appConfig.IncludeUnknown) {
        $arguments += '--include-unknown'
    }

    $updateResult = Invoke-WinGet -Arguments $arguments

    foreach ($line in $updateResult.Output) {
        Write-AppUpdateLog -Level 'INFO' -Message $line
    }

    if ($updateResult.ExitCode -ne 0) {
        $failed = $true
        Write-AppUpdateLog -Level 'ERROR' -Message "winget upgrade --all exited with code $($updateResult.ExitCode)."
    }
    else {
        Write-AppUpdateLog -Level 'SUCCESS' -Message 'WinGet upgrade-all maintenance completed.'
    }

    $results.Add([pscustomobject]@{
        Action   = 'UpgradeAll'
        ExitCode = $updateResult.ExitCode
        Output   = $updateResult.Output
    })
}
elseif ($mode -eq 'AllowList') {
    foreach ($packageId in @($appConfig.Packages)) {
        if ([string]::IsNullOrWhiteSpace([string]$packageId)) {
            continue
        }

        if (@($appConfig.ExcludedPackages) -contains $packageId) {
            Write-AppUpdateLog -Level 'INFO' -Message "Skipped excluded allow-list package: $packageId"
            continue
        }

        $arguments = @(
            'upgrade',
            '--id', [string]$packageId,
            '--exact',
            '--silent',
            '--accept-source-agreements',
            '--accept-package-agreements',
            '--disable-interactivity'
        )

        if ([bool]$appConfig.IncludeUnknown) {
            $arguments += '--include-unknown'
        }

        $updateResult = Invoke-WinGet -Arguments $arguments

        foreach ($line in $updateResult.Output) {
            Write-AppUpdateLog -Level 'INFO' -Message "[$packageId] $line"
        }

        if ($updateResult.ExitCode -ne 0) {
            $failed = $true
            Write-AppUpdateLog -Level 'ERROR' -Message "Package '$packageId' exited with code $($updateResult.ExitCode)."
        }

        $results.Add([pscustomobject]@{
            Action    = 'UpgradePackage'
            PackageId = [string]$packageId
            ExitCode  = $updateResult.ExitCode
            Output    = $updateResult.Output
        })
    }
}
else {
    throw "Unsupported AppUpdates.Mode '$mode'. Use All or AllowList."
}

$summary = [ordered]@{
    ComputerName = $env:COMPUTERNAME
    RunId        = $RunId
    User         = [Security.Principal.WindowsIdentity]::GetCurrent().Name
    AuditOnly    = [bool]$AuditOnly
    Mode         = $mode
    Failed       = $failed
    Completed    = (Get-Date).ToString('o')
    Results      = $results
}

$summary | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $ReportFile -Encoding UTF8

Write-AppUpdateLog -Level 'INFO' -Message "Run completed. Failed=$failed; Report=$ReportFile"

if ($failed) {
    exit 2
}

exit 0
