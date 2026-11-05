<#
.SYNOPSIS
    Runs a single audit-only Desktop Policy Guard validation pass.

.DESCRIPTION
    Executes Start-DesktopPolicyGuard.ps1 with -RunOnce and -AuditOnly against
    the tracked example configuration. No registry values or shortcuts are changed.

.EXAMPLE
    .\Test-DesktopPolicyGuard.ps1

.NOTES
    File Name  : Test-DesktopPolicyGuard.ps1
    Author     : Joel Cottrell
    Version    : 1.0.0
    Updated    : 2026-11-05
    Requires   : Windows PowerShell 5.1 or later

    Repository : https://github.com/joelcottrell/powershell-toolkit
#>

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$serviceScript = Join-Path -Path $PSScriptRoot -ChildPath 'Start-DesktopPolicyGuard.ps1'
$configPath = Join-Path -Path $PSScriptRoot -ChildPath 'Config\config.example.json'

if (-not (Test-Path -LiteralPath $serviceScript -PathType Leaf)) {
    throw "Service script not found: $serviceScript"
}

if (-not (Test-Path -LiteralPath $configPath -PathType Leaf)) {
    throw "Configuration file not found: $configPath"
}

& powershell.exe `
    -NoLogo `
    -NoProfile `
    -ExecutionPolicy Bypass `
    -File $serviceScript `
    -ConfigPath $configPath `
    -RunOnce `
    -AuditOnly

if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}
