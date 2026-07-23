<#
.SYNOPSIS
    Silently removes the per-user Zoom client for every profile on the machine.

.DESCRIPTION
    The Zoom desktop client installs per user, under each profile's AppData, rather than
    machine-wide. A single uninstall therefore leaves it in place for every other user. This
    script walks every profile on the device and, for each one that has Zoom, stops the
    process, removes the per-user uninstall registry key, and deletes the application folder
    and Start Menu shortcut.

    It writes a marker file under ProgramData so an Intune Win32 app can use file-exists
    detection.

    This handles the standard per-user (ZoomUMX) install. It does not remove the separate
    machine-wide Zoom MSI (ZoomInstallerFull / "Zoom" under the 64-bit uninstall hive); if
    your environment uses that, uninstall it through its own product code as well.

.PARAMETER MarkerRoot
    Directory under which the detection marker is written. Defaults to ProgramData.

.EXAMPLE
    .\Uninstall-Zoom.ps1
    Removes Zoom for every user profile on the machine.

.EXAMPLE
    .\Uninstall-Zoom.ps1 -WhatIf
    Reports which profiles have Zoom without removing anything.

.NOTES
    File Name  : Uninstall-Zoom.ps1
    Author     : Joel Cottrell
    Version    : 1.1.0
    Updated    : 2026-07-23
    Requires   : PowerShell 5.1 or later, elevation

    Per-user removal approach adapted from a community SCCM discussion:
    https://www.reddit.com/r/SCCM/comments/fu3q6f/

    Repository : https://github.com/joelcottrell/powershell-toolkit

    ==========================================================================
    REMOTE EXECUTION FROM GITHUB
    ==========================================================================

    Option 1 - Run directly without downloading:

        $u = "https://raw.githubusercontent.com/joelcottrell/powershell-toolkit/main/Endpoint/Intune/Windows/Win32Apps/Zoom/Uninstall-Zoom.ps1"
        Invoke-Expression (Invoke-WebRequest -Uri $u -UseBasicParsing).Content

    Option 2 - Download and run (recommended, allows review before execution):

        $u = "https://raw.githubusercontent.com/joelcottrell/powershell-toolkit/main/Endpoint/Intune/Windows/Win32Apps/Zoom/Uninstall-Zoom.ps1"
        $p = "C:\Scripts\Uninstall-Zoom.ps1"
        New-Item -Path (Split-Path $p) -ItemType Directory -Force | Out-Null
        Invoke-WebRequest -Uri $u -OutFile $p -UseBasicParsing
        & $p

    Option 3 - Scheduled task (refreshes the script on each run):

        $u = "https://raw.githubusercontent.com/joelcottrell/powershell-toolkit/main/Endpoint/Intune/Windows/Win32Apps/Zoom/Uninstall-Zoom.ps1"
        $p = "C:\Scripts\Uninstall-Zoom.ps1"
        $cmd = "Invoke-WebRequest -Uri '$u' -OutFile '$p' -UseBasicParsing; & '$p'"
        $act = New-ScheduledTaskAction -Execute "powershell.exe" `
                   -Argument "-NoProfile -ExecutionPolicy Bypass -Command `"$cmd`""
        $trg = New-ScheduledTaskTrigger -Daily -At 3am
        Register-ScheduledTask -TaskName "Uninstall-Zoom" -Action $act -Trigger $trg `
                   -RunLevel Highest -User "SYSTEM"

    SECURITY: Option 1 executes remote code without review. Option 3 re-downloads on every
    run. Option 2 is the default recommendation. For production, replace 'main' with a
    release tag.

    ==========================================================================
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [string]$MarkerRoot = $env:ProgramData
)

$identity  = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($identity)
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "This script must be run from an elevated PowerShell session."
    exit 1
}

# Detection marker for Intune file-exists detection.
$markerDir = Join-Path $MarkerRoot 'Intune-Zoom-Uninstall'
if (-not (Test-Path -LiteralPath $markerDir)) {
    New-Item -Path $markerDir -ItemType Directory -Force | Out-Null
}
Set-Content -LiteralPath (Join-Path $markerDir 'Output.txt') -Value "Executed $(Get-Date -Format 'u')"

# Map HKEY_USERS so per-user uninstall keys can be reached by SID.
if (-not (Get-PSDrive -Name HKU -ErrorAction SilentlyContinue)) {
    New-PSDrive -Name HKU -PSProvider Registry -Root HKEY_USERS -Scope Script | Out-Null
}

try {
    $profiles = Get-ChildItem -Path (Join-Path $env:SystemDrive 'Users') -Directory |
                Where-Object { $_.Name -notin @('Public', 'Default', 'Default User', 'All Users') }

    foreach ($profile in $profiles) {
        $roaming  = Join-Path $profile.FullName 'AppData\Roaming'
        $zoomPath = Join-Path $roaming 'Zoom'

        if (-not (Test-Path -LiteralPath $zoomPath)) {
            Write-Host "Zoom is not installed for $($profile.Name)." -ForegroundColor DarkGray
            continue
        }

        Write-Host "Zoom found for $($profile.Name). Removing..." -ForegroundColor Yellow

        if (-not $PSCmdlet.ShouldProcess($profile.Name, "Remove per-user Zoom")) { continue }

        Get-Process -Name 'Zoom' -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 3

        # Resolve the profile to a SID for its per-user uninstall key.
        try {
            $sid = (New-Object System.Security.Principal.NTAccount($profile.Name)).Translate(
                        [System.Security.Principal.SecurityIdentifier]).Value
            $uninstallKey = "HKU:\$sid\Software\Microsoft\Windows\CurrentVersion\Uninstall\ZoomUMX"
            if (Test-Path -LiteralPath $uninstallKey) {
                Write-Host "  Removing uninstall registry key" -ForegroundColor DarkGray
                Remove-Item -LiteralPath $uninstallKey -Recurse -Force -ErrorAction SilentlyContinue
            }
        } catch {
            Write-Warning "  Could not resolve a SID for $($profile.Name); skipping its registry key."
        }

        Write-Host "  Removing $zoomPath" -ForegroundColor DarkGray
        Remove-Item -LiteralPath $zoomPath -Recurse -Force -ErrorAction SilentlyContinue

        $shortcut = Join-Path $roaming 'Microsoft\Windows\Start Menu\Programs\Zoom'
        if (Test-Path -LiteralPath $shortcut) {
            Write-Host "  Removing Start Menu shortcut" -ForegroundColor DarkGray
            Remove-Item -LiteralPath $shortcut -Recurse -Force -ErrorAction SilentlyContinue
        }

        Write-Host "  [OK] Zoom removed for $($profile.Name)." -ForegroundColor Green
    }
}
finally {
    if (Get-PSDrive -Name HKU -ErrorAction SilentlyContinue) {
        Remove-PSDrive -Name HKU -Force -ErrorAction SilentlyContinue
    }
}
