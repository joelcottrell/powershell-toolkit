<#
.SYNOPSIS
    Removes the Ubuntu distribution and the Windows Subsystem for Linux feature, then restarts.

.DESCRIPTION
    Unregisters the Ubuntu distribution, removes its AppX package, uninstalls the WSL kernel
    update, disables the Microsoft-Windows-Subsystem-Linux optional feature, and schedules a
    restart.

    Unregistering a distribution permanently deletes its filesystem. Everything inside the
    Ubuntu installation - home directories, installed packages, any work not copied out - is
    destroyed and is not recoverable. The script confirms before doing this unless -Force is
    supplied.

    This deliberately does not remove other installed distributions, the Windows Terminal
    profile, or the Virtual Machine Platform feature, which other software may depend on.

.PARAMETER Distribution
    Distribution to unregister and remove. Defaults to 'ubuntu'.

.PARAMETER RestartDelaySeconds
    Seconds to wait before restarting. Defaults to 60.

.PARAMETER NoRestart
    Skips the restart. Feature removal stays incomplete until the machine is restarted.

.PARAMETER Force
    Skips the confirmation prompt before destroying the distribution filesystem.

.EXAMPLE
    .\Uninstall-WSL2Ubuntu.ps1 -WhatIf
    Shows what would be removed without changing anything.

.EXAMPLE
    .\Uninstall-WSL2Ubuntu.ps1
    Prompts for confirmation, then removes Ubuntu and WSL and restarts after 60 seconds.

.NOTES
    File Name  : Uninstall-WSL2Ubuntu.ps1
    Author     : Joel Cottrell
    Version    : 1.1.0
    Updated    : 2026-07-23
    Requires   : PowerShell 5.1 or later, elevation

    Repository : https://github.com/joelcottrell/powershell-toolkit

    ==========================================================================
    REMOTE EXECUTION FROM GITHUB
    ==========================================================================

    Option 1 - Run directly without downloading:

        $u = "https://raw.githubusercontent.com/joelcottrell/powershell-toolkit/main/Windows/Client/WSL/Uninstall-WSL2Ubuntu.ps1"
        Invoke-Expression (Invoke-WebRequest -Uri $u -UseBasicParsing).Content

    Option 2 - Download and run (recommended, allows review before execution):

        $u = "https://raw.githubusercontent.com/joelcottrell/powershell-toolkit/main/Windows/Client/WSL/Uninstall-WSL2Ubuntu.ps1"
        $p = "C:\Scripts\Uninstall-WSL2Ubuntu.ps1"
        New-Item -Path (Split-Path $p) -ItemType Directory -Force | Out-Null
        Invoke-WebRequest -Uri $u -OutFile $p -UseBasicParsing
        & $p

    Option 3 - Scheduled task (refreshes the script on each run):

        $u = "https://raw.githubusercontent.com/joelcottrell/powershell-toolkit/main/Windows/Client/WSL/Uninstall-WSL2Ubuntu.ps1"
        $p = "C:\Scripts\Uninstall-WSL2Ubuntu.ps1"
        $cmd = "Invoke-WebRequest -Uri '$u' -OutFile '$p' -UseBasicParsing; & '$p' -Force"
        $act = New-ScheduledTaskAction -Execute "powershell.exe" `
                   -Argument "-NoProfile -ExecutionPolicy Bypass -Command `"$cmd`""
        $trg = New-ScheduledTaskTrigger -Daily -At 3am
        Register-ScheduledTask -TaskName "Uninstall-WSL2Ubuntu" -Action $act -Trigger $trg `
                   -RunLevel Highest -User "SYSTEM"

    SECURITY: this script destroys data. Option 1 executes remote code without review and
    Option 3 re-downloads on every run. Option 2 is the default recommendation. For
    production, replace 'main' with a release tag.

    ==========================================================================
#>

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
param(
    [string]$Distribution = 'ubuntu',

    [ValidateRange(0, 86400)]
    [int]$RestartDelaySeconds = 60,

    [switch]$NoRestart,

    [switch]$Force
)

$identity  = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($identity)
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "This script must be run from an elevated PowerShell session."
    exit 1
}

Write-Warning "Unregistering '$Distribution' permanently deletes its filesystem. Anything inside it is unrecoverable."

if (-not ($Force -or $PSCmdlet.ShouldProcess($Distribution, "Unregister distribution and delete its filesystem"))) {
    Write-Host "Cancelled. Nothing was changed." -ForegroundColor DarkYellow
    return
}

Write-Host "Unregistering the $Distribution distribution..." -ForegroundColor Yellow
wsl --unregister $Distribution
if ($LASTEXITCODE -ne 0) {
    Write-Warning "wsl --unregister returned exit code $LASTEXITCODE. Continuing."
}

Write-Host "Removing the $Distribution AppX package..." -ForegroundColor Yellow
$package = Get-AppxPackage -Name '*Ubuntu*' -ErrorAction SilentlyContinue
if ($package) {
    $package | Remove-AppxPackage -ErrorAction Continue
} else {
    Write-Host "No matching AppX package found. Skipping." -ForegroundColor DarkGray
}

Write-Host "Uninstalling the Windows Subsystem for Linux update..." -ForegroundColor Yellow
$log = Join-Path $env:TEMP 'wslupdate-uninstall.log'
Start-Process 'msiexec.exe' -ArgumentList "/x {36EF257E-21D5-44F7-8451-07923A8C465E} /qn /l*v `"$log`"" -Wait -NoNewWindow
Write-Host "Uninstall log: $log" -ForegroundColor DarkGray

Write-Host "Disabling the Windows Subsystem for Linux feature..." -ForegroundColor Yellow
Disable-WindowsOptionalFeature -Online -FeatureName 'Microsoft-Windows-Subsystem-Linux' -NoRestart -ErrorAction Continue | Out-Null

Write-Host "[OK] Removal complete." -ForegroundColor Green

if ($NoRestart) {
    Write-Host "Restart skipped. Feature removal completes on the next restart." -ForegroundColor DarkYellow
    return
}

$message = "This machine will restart in $RestartDelaySeconds seconds to complete removal of the Windows Subsystem for Linux."

Write-Host "Restarting in $RestartDelaySeconds seconds. Run 'shutdown /a' to abort." -ForegroundColor Green
shutdown.exe /r /t $RestartDelaySeconds /c $message
