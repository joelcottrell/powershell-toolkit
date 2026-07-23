<#
.SYNOPSIS
    Installs Windows Subsystem for Linux with the Ubuntu distribution, then restarts.

.DESCRIPTION
    Installs WSL and Ubuntu in a single operation using 'wsl --install -d ubuntu', then
    schedules a restart to complete the installation.

    A restart is required. WSL cannot finish enabling its optional features until the
    machine has rebooted, so the script schedules one rather than leaving the install
    half-applied.

    This deliberately does not set Ubuntu as the default distribution, install any
    packages inside the distribution, or create the initial UNIX user account. The first
    launch of Ubuntu prompts for that account interactively.

.PARAMETER RestartDelaySeconds
    Seconds to wait before restarting. Defaults to 60.

.PARAMETER NoRestart
    Skips the restart entirely. The installation stays incomplete until the machine is
    restarted by some other means.

.EXAMPLE
    .\Install-WSL2Ubuntu.ps1
    Installs WSL and Ubuntu, then restarts after 60 seconds.

.EXAMPLE
    .\Install-WSL2Ubuntu.ps1 -NoRestart
    Installs WSL and Ubuntu and leaves the restart to you.

.NOTES
    File Name  : Install-WSL2Ubuntu.ps1
    Author     : Joel Cottrell
    Version    : 1.1.0
    Updated    : 2026-07-23
    Requires   : PowerShell 5.1 or later, Windows 10 2004 or later, elevation

    Repository : https://github.com/joelcottrell/powershell-toolkit

    ==========================================================================
    REMOTE EXECUTION FROM GITHUB
    ==========================================================================

    Option 1 - Run directly without downloading:

        $u = "https://raw.githubusercontent.com/joelcottrell/powershell-toolkit/main/Windows/Client/WSL/Install-WSL2Ubuntu.ps1"
        Invoke-Expression (Invoke-WebRequest -Uri $u -UseBasicParsing).Content

    Option 2 - Download and run (recommended, allows review before execution):

        $u = "https://raw.githubusercontent.com/joelcottrell/powershell-toolkit/main/Windows/Client/WSL/Install-WSL2Ubuntu.ps1"
        $p = "C:\Scripts\Install-WSL2Ubuntu.ps1"
        New-Item -Path (Split-Path $p) -ItemType Directory -Force | Out-Null
        Invoke-WebRequest -Uri $u -OutFile $p -UseBasicParsing
        & $p

    Option 3 - Scheduled task (refreshes the script on each run):

        $u = "https://raw.githubusercontent.com/joelcottrell/powershell-toolkit/main/Windows/Client/WSL/Install-WSL2Ubuntu.ps1"
        $p = "C:\Scripts\Install-WSL2Ubuntu.ps1"
        $cmd = "Invoke-WebRequest -Uri '$u' -OutFile '$p' -UseBasicParsing; & '$p'"
        $act = New-ScheduledTaskAction -Execute "powershell.exe" `
                   -Argument "-NoProfile -ExecutionPolicy Bypass -Command `"$cmd`""
        $trg = New-ScheduledTaskTrigger -Daily -At 3am
        Register-ScheduledTask -TaskName "Install-WSL2Ubuntu" -Action $act -Trigger $trg `
                   -RunLevel Highest -User "SYSTEM"

    SECURITY: Option 1 executes remote code without review. Option 3 re-downloads on every
    run, so a compromised repository propagates immediately. Option 2 is the default
    recommendation. For production, replace 'main' with a release tag.

    ==========================================================================
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [ValidateRange(0, 86400)]
    [int]$RestartDelaySeconds = 60,

    [switch]$NoRestart
)

# Requires elevation: enabling optional Windows features is a machine-wide change.
$identity  = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($identity)
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "This script must be run from an elevated PowerShell session."
    exit 1
}

Write-Host "Installing Windows Subsystem for Linux with the Ubuntu distribution..." -ForegroundColor Yellow

if ($PSCmdlet.ShouldProcess($env:COMPUTERNAME, "Install WSL and Ubuntu")) {
    wsl --install -d ubuntu

    if ($LASTEXITCODE -ne 0) {
        Write-Error "wsl --install returned exit code $LASTEXITCODE. Nothing was restarted."
        exit $LASTEXITCODE
    }

    Write-Host "[OK] WSL and Ubuntu installed." -ForegroundColor Green
}

if ($NoRestart) {
    Write-Host "Restart skipped. The installation completes on the next restart." -ForegroundColor DarkYellow
    return
}

$message = "This machine will restart in $RestartDelaySeconds seconds to complete the Windows Subsystem for Linux installation."

if ($PSCmdlet.ShouldProcess($env:COMPUTERNAME, "Restart in $RestartDelaySeconds seconds")) {
    Write-Host "Restarting in $RestartDelaySeconds seconds. Run 'shutdown /a' to abort." -ForegroundColor Green
    shutdown.exe /r /t $RestartDelaySeconds /c $message
}
