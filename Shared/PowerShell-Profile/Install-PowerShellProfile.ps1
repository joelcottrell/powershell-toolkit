<#
.SYNOPSIS
    Installs the PowerShell profile selector for the current PowerShell host.
.DESCRIPTION
    Backs up the existing $PROFILE, copies the bootstrap and local profile,
    and leaves remote profile refreshes as an explicit separate action.
.NOTES
    File Name : Install-PowerShellProfile.ps1
    Author    : Joel Cottrell
    Version   : 1.0.0
.EXAMPLE
    .\Install-PowerShellProfile.ps1 -WhatIf
.EXAMPLE
    .\Install-PowerShellProfile.ps1
#>
[CmdletBinding(SupportsShouldProcess=$true,ConfirmImpact='High')]
param()
$ErrorActionPreference = 'Stop'
$source = $PSScriptRoot
$destination = Split-Path -Parent $PROFILE
$bootstrap = Join-Path $source 'Import-RemoteProfile.ps1'
$local = Join-Path $source 'Local-Profile.ps1'
if (-not (Test-Path -LiteralPath $bootstrap) -or -not (Test-Path -LiteralPath $local)) {
    throw 'Run this installer from the folder containing Import-RemoteProfile.ps1 and Local-Profile.ps1.'
}
if ($PSCmdlet.ShouldProcess($PROFILE,'Back up existing profile and install profile selector')) {
    New-Item -Path $destination -ItemType Directory -Force | Out-Null
    if (Test-Path -LiteralPath $PROFILE) {
        $backup = "$PROFILE.backup.$(Get-Date -Format yyyyMMdd-HHmmss)"
        Copy-Item -LiteralPath $PROFILE -Destination $backup -ErrorAction Stop
        Write-Host "Previous profile backed up to: $backup"
    }
    Copy-Item -LiteralPath $bootstrap -Destination $PROFILE -Force
    Copy-Item -LiteralPath $local -Destination (Join-Path $destination 'Local-Profile.ps1') -Force
    Write-Host 'Installed. Restart PowerShell to choose local or full profile.' -ForegroundColor Green
    Write-Host 'To install the reviewed GitHub profile cache, run Update-PowerShellProfile after restarting.'
}
