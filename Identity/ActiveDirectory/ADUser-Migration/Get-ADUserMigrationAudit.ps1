#Requires -Version 5.1
<#
.SYNOPSIS
    Audit one intra-forest Active Directory user migration request.
.DESCRIPTION
    Collects read-only directory evidence and group decisions. When CsvPath is
    omitted, the file picker requires STA. WhatIf skips directory access and writes.
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
.PARAMETER ResumeState
    Prior audit state.json. Validates its hashes and GUID before a fresh audit.
.PARAMETER NoAutoElevate
    Require an already elevated session.
.EXAMPLE
    .Get-ADUserMigrationAudit.ps1 -CsvPath .ExamplesMigration.example.csv -ConfigPath .ConfigMigrationConfig.example.json -GroupMapPath .ConfigGroupMappings.example.csv -WhatIf
.NOTES
    File Name: Get-ADUserMigrationAudit.ps1
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
[CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='High')]
param(
    [string]$CsvPath,
    [string]$ConfigPath,
    [string]$GroupMapPath,
    [string]$OutputRoot,
    [string]$ResumeState,
    [switch]$DryRun,
    [switch]$TestMode,
    [switch]$NoAutoElevate
)
if (-not $ConfigPath) { $ConfigPath = Join-Path $PSScriptRoot 'Config/MigrationConfig.json' }
if (-not $GroupMapPath) { $GroupMapPath = Join-Path $PSScriptRoot 'Config/GroupMappings.csv' }
if (-not $OutputRoot) { $OutputRoot = Join-Path $PSScriptRoot 'Output' }
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'Modules\ADMigration.ADUserMigration.psm1') -Force
try {
    if ([Environment]::OSVersion.Platform -ne 'Win32NT') { throw 'Run on Windows with Windows PowerShell 5.1.' }
    if ($PSVersionTable.PSEdition -ne 'Desktop') { throw 'Use Windows PowerShell 5.1 (powershell.exe), not pwsh.exe.' }
    Write-ADMigrationSection 'ACTIVE DIRECTORY USER MIGRATION TOOL 1.0.13'
    Write-Host 'READ-ONLY AUDIT: NO ACTIVE DIRECTORY CHANGES WILL OCCUR' -ForegroundColor Yellow
    if (-not $WhatIfPreference -and -not (Test-ADMigrationProcessElevated)) {
        if ($NoAutoElevate) { throw 'This session is not elevated. Start Windows PowerShell as administrator under the same authorized account.' }
        $forward=@{ConfigPath=$ConfigPath;GroupMapPath=$GroupMapPath;OutputRoot=$OutputRoot;DryRun=[bool]$DryRun;TestMode=[bool]$TestMode}
        if ($CsvPath) { $forward.CsvPath=$CsvPath }
        if ($ResumeState) { $forward.ResumeState=$ResumeState }
        foreach ($name in @('Confirm','Verbose')) { if ($PSBoundParameters.ContainsKey($name)) { $forward[$name]=[bool]$PSBoundParameters[$name] } }
        Start-ADMigrationElevatedAudit -PackageRoot $PSScriptRoot -Parameters $forward
        return
    }
    Write-ADMigrationSection 'LOAD AND REVIEW SINGLE-USER CSV REQUEST'
    if (-not $CsvPath) {
        if ([Threading.Thread]::CurrentThread.ApartmentState -ne 'STA') { throw 'File picker requires -STA, or supply -CsvPath.' }
        Add-Type -AssemblyName System.Windows.Forms
        $dialog = New-Object System.Windows.Forms.OpenFileDialog
        try {
            $dialog.Filter = 'CSV files (*.csv)|*.csv'
            $dialog.Title = 'Select the single-user migration CSV'
            if ($dialog.ShowDialog() -ne 'OK') { Write-Host 'Selection cancelled. No audit started.'; exit 0 }
            $CsvPath = $dialog.FileName
        } finally { $dialog.Dispose() }
    }
    $inputData = Read-ADMigrationInput -CsvPath $CsvPath -ConfigPath $ConfigPath -GroupMapPath $GroupMapPath
    if (-not $WhatIfPreference) { Assert-ADMigrationSecurityPreflight -ForestRoot $inputData.Config.ForestRoot }
    $inputData.Row | Format-List | Out-Host
    Write-Host ('Source domain: '+$inputData.Direction.SourceDomain)
    Write-Host ('Target domain: '+$inputData.Direction.TargetDomain)
    # ShouldProcess covers local evidence creation. WhatIf does not query AD or write files.
    if (-not $PSCmdlet.ShouldProcess(($inputData.Row.SamAccountName+' -> '+$inputData.Row.TargetOU), ('Create audit evidence under '+$OutputRoot+' and query the requested user plus group metadata/nesting in both domains'))) { exit 0 }
    $result = Invoke-ADMigrationAudit -InputData $inputData -OutputRoot $OutputRoot -ResumeState $ResumeState
    Write-Host ('Status: {0}. Evidence: {1}' -f $result.Status, $result.Directory)
    if ($result.Status -eq 'Blocked') { exit 2 }
    exit 0
} catch {
    Write-Error -ErrorRecord $_ -ErrorAction Continue
    exit 1
}
