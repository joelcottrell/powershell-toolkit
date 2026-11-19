#Requires -Version 5.1
<#
.SYNOPSIS
    Start the audit from the validated UAC handoff.
.DESCRIPTION
    Internal launcher. Verifies that the elevated identity matches the request
    and forwards only approved parameters to the audit script.
.PARAMETER RequestPath
    Request.json created by the audit UAC handoff.
.EXAMPLE
    .Start-ADMigrationElevatedSession.ps1 -RequestPath $requestPath
.NOTES
    File Name: Start-ADMigrationElevatedSession.ps1
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
[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$RequestPath)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
try {
    $request=Get-Content -LiteralPath $RequestPath -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($request.SchemaVersion -ne 1) { throw 'Unsupported elevation request.' }
    $identity=[Security.Principal.WindowsIdentity]::GetCurrent()
    try {
        if ($identity.User.Value -ne $request.ExpectedSID) { throw 'UAC used a different account. Start the tool directly under the intended administrator account.' }
    } finally { $identity.Dispose() }
    $parameters=@{}
    $pathParameters=@('CsvPath','ConfigPath','GroupMapPath','OutputRoot','ResumeState')
    $switchParameters=@('DryRun','TestMode','Confirm','WhatIf','Verbose')
    foreach ($property in $request.Parameters.PSObject.Properties) {
        if ($pathParameters -contains $property.Name) { $parameters[$property.Name]=[string]$property.Value }
        elseif ($switchParameters -contains $property.Name) {
            if ($property.Value -isnot [bool]) { throw ('Expected boolean for '+$property.Name) }
            $parameters[$property.Name]=[bool]$property.Value
        } else { throw ('Unsupported elevation parameter: '+$property.Name) }
    }
    $parameters.NoAutoElevate=$true
    # Remove only the generated request and empty directory before running audit.
    if ([IO.Path]::GetFileName($RequestPath) -ne 'Request.json' -or [IO.Path]::GetFileName([IO.Path]::GetDirectoryName($RequestPath)) -notlike 'ADMigrationElevation-*') { throw 'Unexpected elevation request path.' }
    [IO.File]::Delete($RequestPath)
    [IO.Directory]::Delete([IO.Path]::GetDirectoryName($RequestPath))
    Set-Location -LiteralPath $PSScriptRoot
    & (Join-Path $PSScriptRoot 'Get-ADUserMigrationAudit.ps1') @parameters
    Write-Host ('Audit process exit code: '+$LASTEXITCODE)
} catch {
    Write-Error -Message $_.Exception.Message -ErrorAction Continue
}
# powershell.exe -NoExit keeps the console available for review.
