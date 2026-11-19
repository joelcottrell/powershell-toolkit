#Requires -Version 5.1
<#
.SYNOPSIS
    Preview or explicitly execute one intra-forest Active Directory user move.
.DESCRIPTION
    Preview reads live AD. Execution requires a reviewed plan, fresh audit and
    typed confirmation. Resume reconciles an already attempted, target-only move.
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
    Independently known source GUID. Execution uses the saved plan GUID if omitted.
.PARAMETER PlanPath
    Path to the exact reviewed execution plan.
.PARAMETER Execute
    Select the write workflow.
.PARAMETER Resume
    Reconcile post-move steps using the original execution plan and output root.
.EXAMPLE
    .Move-ADUserAccount.ps1 -CsvPath .ExamplesMigration.example.csv -ConfigPath .ConfigMigrationConfig.example.json -GroupMapPath .ConfigGroupMappings.example.csv -WhatIf
.NOTES
    File Name: Move-ADUserAccount.ps1
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
    [Parameter(Mandatory)][string]$CsvPath,
    [guid]$ExpectedUserGUID=[guid]::Empty,
    [string]$PlanPath,
    [switch]$Execute,
    [switch]$Resume,
    [switch]$DryRun,
    [switch]$TestMode,
    [string]$OutputRoot,
    [string]$ConfigPath,
    [string]$GroupMapPath
)
if (-not $ConfigPath) { $ConfigPath = Join-Path $PSScriptRoot 'Config/MigrationConfig.json' }
if (-not $GroupMapPath) { $GroupMapPath = Join-Path $PSScriptRoot 'Config/GroupMappings.csv' }
if (-not $OutputRoot) { $OutputRoot = Join-Path $PSScriptRoot 'Output' }
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
try {
    if ($PSVersionTable.PSEdition -ne 'Desktop' -or [Environment]::OSVersion.Platform -ne 'Win32NT') { throw 'Use elevated Windows PowerShell 5.1 under your authorized administrative account.' }
    if (($DryRun -or $TestMode) -and ($Execute -or $Resume)) { throw 'DryRun/TestMode cannot be combined with Execute/Resume.' }
    if ($Resume -and -not $Execute) { throw 'Resume requires Execute and the original PlanPath.' }
    if ($Execute -and -not $PlanPath) { throw 'Execute requires the reviewed ExecutionPlan.json.' }
    Import-Module (Join-Path $PSScriptRoot 'Modules/ADMigration.ADUserMigration.psm1') -Force
    $inputData=Read-ADMigrationInput $CsvPath $ConfigPath $GroupMapPath
    if ($WhatIfPreference) { [void]$PSCmdlet.ShouldProcess($inputData.Row.SamAccountName,'Preview or execute the explicitly selected mode; WhatIf makes no AD queries or file writes');return }
    Assert-ADMigrationSecurityPreflight -ForestRoot $InputData.Config.ForestRoot
    if ($Execute -and $ExpectedUserGUID -eq [guid]::Empty) { $ExpectedUserGUID=[guid](Get-Content -LiteralPath $PlanPath -Raw -Encoding UTF8 | ConvertFrom-Json).GUID }
    if ($Execute) { Invoke-ADMigrationExecution -InputData $inputData -ExpectedUserGUID $ExpectedUserGUID -PlanPath $PlanPath -OutputRoot $OutputRoot -Resume:$Resume -Confirm:($ConfirmPreference -ne 'None') }
    else { New-UserMigrationExecutionPreview -InputData $inputData -ExpectedUserGUID $ExpectedUserGUID -OutputRoot $OutputRoot }
} catch { Write-Host ('Failure location: '+$_.ScriptStackTrace) -ForegroundColor Yellow; Write-Error -ErrorRecord $_ -ErrorAction Continue;exit 1 }
