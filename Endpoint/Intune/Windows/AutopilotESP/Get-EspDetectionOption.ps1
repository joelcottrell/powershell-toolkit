<#
.SYNOPSIS
    Detects whether the device is currently in the Autopilot Enrollment Status Page phase.

.DESCRIPTION
    Used as an Intune Win32 app requirement rule so that an app - typically an updates app
    such as UpdateOS - runs only during Windows Autopilot provisioning, not on every device
    afterwards.

    During the Autopilot ESP the only interactive account present is 'defaultuser0' (or
    'defaultuser1' on some builds). The script inspects the owner of each running
    explorer.exe and writes 'True' when one of those accounts is found, 'False' otherwise.
    Intune reads that output through a string-equals requirement rule.

    This is a read-only detection script. It changes nothing on the device.

.OUTPUTS
    Writes 'True' or 'False' to the host for Intune to evaluate.

.EXAMPLE
    .\Get-EspDetectionOption.ps1
    Writes True if the device is in the Autopilot ESP phase, otherwise False.

.NOTES
    File Name  : Get-EspDetectionOption.ps1
    Author     : Joel Cottrell
    Version    : 1.1.0
    Updated    : 2026-07-23
    Requires   : PowerShell 5.1 or later

    Pairs with the UpdateOS app by Michael Niehaus (third party):
    https://github.com/mtniehaus/UpdateOS

    Approach informed by:
    https://oofhours.com/2024/01/26/installing-updates-during-autopilot-windows-11-edition-revisited-again/

    Repository : https://github.com/joelcottrell/powershell-toolkit

    ==========================================================================
    REMOTE EXECUTION FROM GITHUB
    ==========================================================================

    Option 1 - Run directly without downloading:

        $u = "https://raw.githubusercontent.com/joelcottrell/powershell-toolkit/main/Endpoint/Intune/Windows/AutopilotESP/Get-EspDetectionOption.ps1"
        Invoke-Expression (Invoke-WebRequest -Uri $u -UseBasicParsing).Content

    Option 2 - Download and run (recommended, allows review before execution):

        $u = "https://raw.githubusercontent.com/joelcottrell/powershell-toolkit/main/Endpoint/Intune/Windows/AutopilotESP/Get-EspDetectionOption.ps1"
        $p = "C:\Scripts\Get-EspDetectionOption.ps1"
        New-Item -Path (Split-Path $p) -ItemType Directory -Force | Out-Null
        Invoke-WebRequest -Uri $u -OutFile $p -UseBasicParsing
        & $p

    Option 3 - Scheduled task (refreshes the script on each run):

        $u = "https://raw.githubusercontent.com/joelcottrell/powershell-toolkit/main/Endpoint/Intune/Windows/AutopilotESP/Get-EspDetectionOption.ps1"
        $p = "C:\Scripts\Get-EspDetectionOption.ps1"
        $cmd = "Invoke-WebRequest -Uri '$u' -OutFile '$p' -UseBasicParsing; & '$p'"
        $act = New-ScheduledTaskAction -Execute "powershell.exe" `
                   -Argument "-NoProfile -ExecutionPolicy Bypass -Command `"$cmd`""
        $trg = New-ScheduledTaskTrigger -Daily -At 3am
        Register-ScheduledTask -TaskName "Get-EspDetectionOption" -Action $act -Trigger $trg `
                   -RunLevel Highest -User "SYSTEM"

    SECURITY: Option 1 executes remote code without review. Option 3 re-downloads on every
    run. Option 2 is the default recommendation. For production, replace 'main' with a
    release tag.

    ==========================================================================
#>

[CmdletBinding()]
param()

$esp = $false

# During the Autopilot ESP the interactive shell runs as defaultuser0/defaultuser1.
$explorerProcesses = @(
    Get-CimInstance -ClassName Win32_Process -Filter "Name = 'explorer.exe'" -ErrorAction SilentlyContinue
)

foreach ($proc in $explorerProcesses) {
    $owner = (Invoke-CimMethod -InputObject $proc -MethodName GetOwner -ErrorAction SilentlyContinue).User
    if ($owner -in @('defaultuser0', 'defaultuser1')) {
        $esp = $true
        break
    }
}

Write-Host $esp
