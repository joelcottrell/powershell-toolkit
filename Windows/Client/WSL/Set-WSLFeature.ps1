<#
.SYNOPSIS
    Enables or disables the Windows Subsystem for Linux optional feature.

.DESCRIPTION
    Toggles the Microsoft-Windows-Subsystem-Linux optional Windows feature. Enabling
    includes all parent features; neither operation restarts the machine.

    This only touches the Windows feature. It does not install, remove, or modify any
    Linux distribution. To install WSL together with Ubuntu, use Install-WSL2Ubuntu.ps1;
    to remove a distribution and its filesystem, use Uninstall-WSL2Ubuntu.ps1.

    A restart is required before the change takes effect.

.PARAMETER State
    'Enabled' to enable the feature, 'Disabled' to disable it.

.EXAMPLE
    .\Set-WSLFeature.ps1 -State Enabled
    Enables the feature. Restart to apply.

.EXAMPLE
    .\Set-WSLFeature.ps1 -State Disabled -WhatIf
    Shows what would change without applying it.

.NOTES
    File Name  : Set-WSLFeature.ps1
    Author     : David Brook
    Migrated   : Joel Cottrell
    Version    : 1.1.0
    Updated    : 2026-07-23
    Requires   : PowerShell 5.1 or later, elevation

    Original author is David Brook. Retained and corrected here rather than claimed as
    original work: the previous version could not be parsed by PowerShell because its
    param block declared a type with no variable name.

    Repository : https://github.com/joelcottrell/powershell-toolkit

    ==========================================================================
    REMOTE EXECUTION FROM GITHUB
    ==========================================================================

    Option 1 - Run directly without downloading:

        $u = "https://raw.githubusercontent.com/joelcottrell/powershell-toolkit/main/Windows/Client/WSL/Set-WSLFeature.ps1"
        Invoke-Expression (Invoke-WebRequest -Uri $u -UseBasicParsing).Content

    Option 2 - Download and run (recommended, allows review before execution):

        $u = "https://raw.githubusercontent.com/joelcottrell/powershell-toolkit/main/Windows/Client/WSL/Set-WSLFeature.ps1"
        $p = "C:\Scripts\Set-WSLFeature.ps1"
        New-Item -Path (Split-Path $p) -ItemType Directory -Force | Out-Null
        Invoke-WebRequest -Uri $u -OutFile $p -UseBasicParsing
        & $p -State Enabled

    Option 3 - Scheduled task (refreshes the script on each run):

        $u = "https://raw.githubusercontent.com/joelcottrell/powershell-toolkit/main/Windows/Client/WSL/Set-WSLFeature.ps1"
        $p = "C:\Scripts\Set-WSLFeature.ps1"
        $cmd = "Invoke-WebRequest -Uri '$u' -OutFile '$p' -UseBasicParsing; & '$p' -State Enabled"
        $act = New-ScheduledTaskAction -Execute "powershell.exe" `
                   -Argument "-NoProfile -ExecutionPolicy Bypass -Command `"$cmd`""
        $trg = New-ScheduledTaskTrigger -Daily -At 3am
        Register-ScheduledTask -TaskName "Set-WSLFeature" -Action $act -Trigger $trg `
                   -RunLevel Highest -User "SYSTEM"

    SECURITY: Option 1 executes remote code without review. Option 3 re-downloads on every
    run. Option 2 is the default recommendation. For production, replace 'main' with a
    release tag.

    ==========================================================================
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('Enabled', 'Disabled')]
    [string]$State
)

$identity  = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($identity)
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "This script must be run from an elevated PowerShell session."
    exit 1
}

$featureName = 'Microsoft-Windows-Subsystem-Linux'

if ($PSCmdlet.ShouldProcess($featureName, "Set feature state to $State")) {
    if ($State -eq 'Enabled') {
        Write-Host "Enabling $featureName..." -ForegroundColor Yellow
        Enable-WindowsOptionalFeature -Online -FeatureName $featureName -All -NoRestart | Out-Null
    } else {
        Write-Host "Disabling $featureName..." -ForegroundColor Yellow
        Disable-WindowsOptionalFeature -Online -FeatureName $featureName -NoRestart | Out-Null
    }

    Write-Host "[OK] Feature set to $State. Restart to apply." -ForegroundColor Green
}
