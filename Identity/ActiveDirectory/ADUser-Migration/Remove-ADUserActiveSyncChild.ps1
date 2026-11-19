#Requires -Version 5.1
<#
.SYNOPSIS
    Preview or explicitly execute individual ActiveSync child deletions.
.DESCRIPTION
    The default is live read-only preview. Execution requires a fresh saved plan
    and typed confirmation. Snapshots serve as evidence.
.PARAMETER CsvPath
    Path to a CSV containing exactly one account.
.PARAMETER ConfigPath
    Path to the reviewed local MigrationConfig.json.
.PARAMETER GroupMapPath
    Path to the reviewed local GroupMappings.csv.
.PARAMETER OutputRoot
    Private evidence and state directory. Keep the same location for recovery.
.PARAMETER DryRun
    Select the live read-only workflow.
.PARAMETER TestMode
    Select the live read-only workflow. Use the offline test runner for mocks.
.PARAMETER ExpectedUserGUID
    GUID from the migration audit.
.PARAMETER PlanPath
    Path to the exact reviewed cleanup preview.
.PARAMETER Execute
    Delete only the individually approved and revalidated ActiveSync children.
.EXAMPLE
    .Remove-ADUserActiveSyncChild.ps1 -CsvPath .ExamplesMigration.csv -ExpectedUserGUID $userGuid
.NOTES
    File Name: Remove-ADUserActiveSyncChild.ps1
    Author: Joel Cottrell
    Version: 1.0.13
    Updated: 2026-11-19
    Requires: Elevated Windows PowerShell 5.1 and RSAT ActiveDirectory for live operations.
    Repository: https://github.com/joelcottrell/powershell-toolkit
    Remote execution options:
    1. Direct raw execution is unsupported. The project requires sibling modules.
    2. Download the full project at a pinned commit, review it, and run locally.
    3. Scheduled re-download is unsupported. The operator must review each plan.
#>
[CmdletBinding(SupportsShouldProcess=$true,ConfirmImpact='High')]
param(
    [Parameter(Mandatory=$true)][string]$CsvPath,
    [Parameter(Mandatory=$true)][guid]$ExpectedUserGUID,
    [string]$ConfigPath,
    [string]$GroupMapPath,
    [string]$OutputRoot,
    [string]$PlanPath,
    [switch]$Execute,
    [switch]$DryRun,
    [switch]$TestMode
)
if (-not $ConfigPath) { $ConfigPath = Join-Path $PSScriptRoot 'Config/MigrationConfig.json' }
if (-not $GroupMapPath) { $GroupMapPath = Join-Path $PSScriptRoot 'Config/GroupMappings.csv' }
if (-not $OutputRoot) { $OutputRoot = Join-Path $PSScriptRoot 'Output' }
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
try {
    if ([Environment]::OSVersion.Platform -ne 'Win32NT' -or $PSVersionTable.PSEdition -ne 'Desktop') { throw 'Use elevated Windows PowerShell 5.1 under your authorized administrative account.' }
    if ($Execute -and ($DryRun -or $TestMode)) { throw 'Execute cannot be combined with DryRun/TestMode.' }
    Import-Module (Join-Path $PSScriptRoot 'Modules\ADMigration.ADUserMigration.psm1') -Force
    $inputData=Read-ADMigrationInput $CsvPath $ConfigPath $GroupMapPath
    $args105=@{InputData=$inputData;ExpectedUserGUID=$ExpectedUserGUID;OutputRoot=$OutputRoot;PlanPath=$PlanPath;Execute=[bool]$Execute;WhatIf=[bool]$WhatIfPreference}
    if ($PSBoundParameters.ContainsKey('Confirm')) { $args105.Confirm=[bool]$PSBoundParameters['Confirm'] }
    $result=Invoke-ADMigrationActiveSyncCleanup @args105
    $result | Format-List | Out-Host
} catch { Write-Error -ErrorRecord $_ -ErrorAction Continue; exit 1 }
