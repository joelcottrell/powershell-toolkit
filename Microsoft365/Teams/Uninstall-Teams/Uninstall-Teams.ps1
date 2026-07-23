<#
.SYNOPSIS
    Removes the classic Teams machine-wide installer and the per-user classic Teams client.

.DESCRIPTION
    Uninstalls the "Teams Machine-Wide Installer" and the classic Teams client for the
    current user. Written for the classic (Teams 1.0) client, which installs per user under
    AppData and reinstalls itself from the machine-wide installer at each logon unless that
    installer is removed first.

    The machine-wide installer is removed through its MSI product, located with
    Get-CimInstance against Win32_Product's provider rather than Win32_Product directly,
    which avoids the full MSI consistency check the latter triggers on every installed
    product.

    This targets the classic client only. It does not remove the new Teams (Teams 2.x)
    MSIX package, which is serviced by the Store and removed with Get-AppxPackage /
    Remove-AppxProvisionedPackage instead.

.PARAMETER SkipMachineWide
    Removes only the current user's client and leaves the machine-wide installer in place.

.EXAMPLE
    .\Uninstall-Teams.ps1
    Removes the machine-wide installer and the current user's classic Teams client.

.EXAMPLE
    .\Uninstall-Teams.ps1 -WhatIf
    Reports what would be removed without changing anything.

.NOTES
    File Name  : Uninstall-Teams.ps1
    Author     : Joel Cottrell
    Version    : 1.1.0
    Updated    : 2026-07-23
    Requires   : PowerShell 5.1 or later, elevation for the machine-wide installer

    Repository : https://github.com/joelcottrell/powershell-toolkit

    ==========================================================================
    REMOTE EXECUTION FROM GITHUB
    ==========================================================================

    Option 1 - Run directly without downloading:

        $u = "https://raw.githubusercontent.com/joelcottrell/powershell-toolkit/main/Microsoft365/Teams/Uninstall-Teams/Uninstall-Teams.ps1"
        Invoke-Expression (Invoke-WebRequest -Uri $u -UseBasicParsing).Content

    Option 2 - Download and run (recommended, allows review before execution):

        $u = "https://raw.githubusercontent.com/joelcottrell/powershell-toolkit/main/Microsoft365/Teams/Uninstall-Teams/Uninstall-Teams.ps1"
        $p = "C:\Scripts\Uninstall-Teams.ps1"
        New-Item -Path (Split-Path $p) -ItemType Directory -Force | Out-Null
        Invoke-WebRequest -Uri $u -OutFile $p -UseBasicParsing
        & $p

    Option 3 - Scheduled task (refreshes the script on each run):

        $u = "https://raw.githubusercontent.com/joelcottrell/powershell-toolkit/main/Microsoft365/Teams/Uninstall-Teams/Uninstall-Teams.ps1"
        $p = "C:\Scripts\Uninstall-Teams.ps1"
        $cmd = "Invoke-WebRequest -Uri '$u' -OutFile '$p' -UseBasicParsing; & '$p'"
        $act = New-ScheduledTaskAction -Execute "powershell.exe" `
                   -Argument "-NoProfile -ExecutionPolicy Bypass -Command `"$cmd`""
        $trg = New-ScheduledTaskTrigger -Daily -At 3am
        Register-ScheduledTask -TaskName "Uninstall-Teams" -Action $act -Trigger $trg `
                   -RunLevel Highest -User "SYSTEM"

    SECURITY: Option 1 executes remote code without review. Option 3 re-downloads on every
    run. Option 2 is the default recommendation. For production, replace 'main' with a
    release tag.

    ==========================================================================
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [switch]$SkipMachineWide
)

function Uninstall-ClassicTeamsClient {
    param([Parameter(Mandatory = $true)][string]$TeamsPath)

    $updater = Join-Path $TeamsPath 'Update.exe'
    if (-not (Test-Path -LiteralPath $updater)) {
        Write-Host "No Teams updater at $updater. Skipping." -ForegroundColor DarkGray
        return
    }

    try {
        Write-Host "Uninstalling the classic Teams client at $TeamsPath..." -ForegroundColor Yellow
        $proc = Start-Process -FilePath $updater -ArgumentList '--uninstall /s' -PassThru -Wait -ErrorAction Stop
        if ($proc.ExitCode -ne 0) {
            Write-Error "Teams client uninstall returned exit code $($proc.ExitCode)."
        } else {
            Write-Host "[OK] Classic Teams client removed." -ForegroundColor Green
        }
    } catch {
        Write-Error $_.Exception.Message
    }
}

# --- Machine-wide installer (MSI) ---
if (-not $SkipMachineWide) {
    $identity  = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Warning "Not elevated. Skipping the machine-wide installer; only the current user's client will be removed."
    } else {
        Write-Host "Looking for the Teams Machine-Wide Installer..." -ForegroundColor Yellow
        # Query the MSI provider by name rather than enumerating Win32_Product, which
        # runs a consistency check against every installed product.
        $machineWide = Get-CimInstance -ClassName Win32_Product `
            -Filter "Name = 'Teams Machine-Wide Installer'" -ErrorAction SilentlyContinue

        if ($machineWide) {
            if ($PSCmdlet.ShouldProcess('Teams Machine-Wide Installer', 'Uninstall MSI')) {
                $result = Invoke-CimMethod -InputObject $machineWide -MethodName Uninstall
                if ($result.ReturnValue -eq 0) {
                    Write-Host "[OK] Teams Machine-Wide Installer removed." -ForegroundColor Green
                } else {
                    Write-Error "Machine-wide uninstall returned code $($result.ReturnValue)."
                }
            }
        } else {
            Write-Host "Teams Machine-Wide Installer not present." -ForegroundColor DarkGray
        }
    }
}

# --- Current user's classic client ---
$localAppData = Join-Path $env:LOCALAPPDATA 'Microsoft\Teams'
$programData  = Join-Path $env:ProgramData  "$env:USERNAME\Microsoft\Teams"

if (Test-Path -LiteralPath (Join-Path $localAppData 'Current\Teams.exe')) {
    if ($PSCmdlet.ShouldProcess($localAppData, 'Uninstall classic Teams client')) {
        Uninstall-ClassicTeamsClient -TeamsPath $localAppData
    }
} elseif (Test-Path -LiteralPath (Join-Path $programData 'Current\Teams.exe')) {
    if ($PSCmdlet.ShouldProcess($programData, 'Uninstall classic Teams client')) {
        Uninstall-ClassicTeamsClient -TeamsPath $programData
    }
} else {
    Write-Warning "No classic Teams client installation found for the current user."
}
