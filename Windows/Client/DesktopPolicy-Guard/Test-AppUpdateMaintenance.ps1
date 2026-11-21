<#
.SYNOPSIS
    Runs an audit-only WinGet application update maintenance pass.

.DESCRIPTION
    Executes Start-AppUpdateMaintenance.ps1 with -AuditOnly. No application
    updates are installed and no exclusion pins are created.

.PARAMETER ConfigPath
    Optional configuration path. Defaults to the tracked example.

.EXAMPLE
    .\Test-AppUpdateMaintenance.ps1

.NOTES
    File Name  : Test-AppUpdateMaintenance.ps1
    Author     : Joel Cottrell
    Version    : 1.0.0
    Updated    : 2026-11-05
    Requires   : PowerShell 7 or later; WinGet

    Repository : https://github.com/joelcottrell/powershell-toolkit
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string]$ConfigPath = (Join-Path -Path $PSScriptRoot -ChildPath 'Config\config.example.json')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptPath = Join-Path -Path $PSScriptRoot -ChildPath 'Start-AppUpdateMaintenance.ps1'

if (-not (Test-Path -LiteralPath $scriptPath -PathType Leaf)) {
    throw "App Update Maintenance script not found: $scriptPath"
}

& $scriptPath -ConfigPath $ConfigPath -AuditOnly
exit $LASTEXITCODE
