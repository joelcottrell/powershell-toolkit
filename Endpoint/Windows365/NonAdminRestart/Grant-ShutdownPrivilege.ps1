<#
.SYNOPSIS
    Grants the shutdown privilege to a security principal so non-administrators can restart.

.DESCRIPTION
    Adds a security principal to the SeShutdownPrivilege user right in local security
    policy, allowing standard users to restart the machine. Written for Windows 365 Cloud
    PCs, where users frequently have no other way to recover a wedged session, but it
    applies to any Windows device.

    The script exports the current local security policy with secedit, adds the principal's
    SID to the SeShutdownPrivilege line if it is not already present, and imports the
    modified policy back.

    It is idempotent. If the principal already holds the right, nothing is written.

    This modifies local security policy only. On a device managed by Group Policy or an
    Intune security baseline that also defines SeShutdownPrivilege, the managed policy wins
    at the next refresh and silently reverts this change.

.PARAMETER Principal
    Security principal to grant the right to. Defaults to the local 'Users' group.

.EXAMPLE
    .\Grant-ShutdownPrivilege.ps1 -WhatIf
    Shows whether a change is needed without applying it.

.EXAMPLE
    .\Grant-ShutdownPrivilege.ps1
    Grants the shutdown privilege to the local Users group.

.EXAMPLE
    .\Grant-ShutdownPrivilege.ps1 -Principal "CONTOSO\Cloud PC Users"
    Grants the right to a specific domain group.

.NOTES
    File Name  : Grant-ShutdownPrivilege.ps1
    Author     : Joel Cottrell
    Version    : 1.1.0
    Updated    : 2026-07-23
    Requires   : PowerShell 5.1 or later, elevation

    Repository : https://github.com/joelcottrell/powershell-toolkit

    ==========================================================================
    REMOTE EXECUTION FROM GITHUB
    ==========================================================================

    Option 1 - Run directly without downloading:

        $u = "https://raw.githubusercontent.com/joelcottrell/powershell-toolkit/main/Endpoint/Windows365/NonAdminRestart/Grant-ShutdownPrivilege.ps1"
        Invoke-Expression (Invoke-WebRequest -Uri $u -UseBasicParsing).Content

    Option 2 - Download and run (recommended, allows review before execution):

        $u = "https://raw.githubusercontent.com/joelcottrell/powershell-toolkit/main/Endpoint/Windows365/NonAdminRestart/Grant-ShutdownPrivilege.ps1"
        $p = "C:\Scripts\Grant-ShutdownPrivilege.ps1"
        New-Item -Path (Split-Path $p) -ItemType Directory -Force | Out-Null
        Invoke-WebRequest -Uri $u -OutFile $p -UseBasicParsing
        & $p

    Option 3 - Scheduled task (refreshes the script on each run):

        $u = "https://raw.githubusercontent.com/joelcottrell/powershell-toolkit/main/Endpoint/Windows365/NonAdminRestart/Grant-ShutdownPrivilege.ps1"
        $p = "C:\Scripts\Grant-ShutdownPrivilege.ps1"
        $cmd = "Invoke-WebRequest -Uri '$u' -OutFile '$p' -UseBasicParsing; & '$p'"
        $act = New-ScheduledTaskAction -Execute "powershell.exe" `
                   -Argument "-NoProfile -ExecutionPolicy Bypass -Command `"$cmd`""
        $trg = New-ScheduledTaskTrigger -Daily -At 3am
        Register-ScheduledTask -TaskName "Grant-ShutdownPrivilege" -Action $act -Trigger $trg `
                   -RunLevel Highest -User "SYSTEM"

    SECURITY: Option 1 executes remote code without review. Option 3 re-downloads on every
    run. Option 2 is the default recommendation. For production, replace 'main' with a
    release tag.

    ==========================================================================
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [ValidateNotNullOrEmpty()]
    [string]$Principal = 'Users'
)

$identity  = [Security.Principal.WindowsIdentity]::GetCurrent()
$winPrincipal = New-Object Security.Principal.WindowsPrincipal($identity)
if (-not $winPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "This script must be run from an elevated PowerShell session."
    exit 1
}

# Resolve the principal to a SID up front - a typo here should fail before we touch policy.
try {
    $account = New-Object System.Security.Principal.NTAccount($Principal)
    $sid     = $account.Translate([System.Security.Principal.SecurityIdentifier]).Value
} catch {
    Write-Error "Could not resolve '$Principal' to a SID: $($_.Exception.Message)"
    exit 1
}

Write-Host "Principal '$Principal' resolves to $sid" -ForegroundColor DarkGray

$export = Join-Path $env:TEMP ("secpol_{0}.inf" -f [System.IO.Path]::GetRandomFileName())
$db     = Join-Path $env:TEMP ("secpol_{0}.sdb" -f [System.IO.Path]::GetRandomFileName())

try {
    secedit.exe /export /cfg $export /quiet
    if (-not (Test-Path -LiteralPath $export)) {
        Write-Error "secedit failed to export the local security policy."
        exit 1
    }

    $settings = Get-Content -LiteralPath $export
    $line     = $settings | Where-Object { $_ -match '^SeShutdownPrivilege' } | Select-Object -First 1

    if (-not $line) {
        Write-Error "SeShutdownPrivilege was not found in the exported policy. Nothing changed."
        exit 1
    }

    if ($line -match [regex]::Escape($sid)) {
        Write-Host "[OK] '$Principal' already holds the shutdown privilege. No change needed." -ForegroundColor Green
        return
    }

    if (-not $PSCmdlet.ShouldProcess($Principal, "Grant SeShutdownPrivilege")) {
        Write-Host "Would grant the shutdown privilege to '$Principal'." -ForegroundColor DarkYellow
        return
    }

    $updated = $settings | ForEach-Object {
        if ($_ -match '^SeShutdownPrivilege') { "$_,*$sid" } else { $_ }
    }

    $updated | Set-Content -LiteralPath $export -Encoding Unicode

    secedit.exe /configure /db $db /cfg $export /areas USER_RIGHTS /quiet
    if ($LASTEXITCODE -ne 0) {
        Write-Error "secedit /configure returned exit code $LASTEXITCODE."
        exit $LASTEXITCODE
    }

    Write-Host "[OK] Granted the shutdown privilege to '$Principal'." -ForegroundColor Green
    Write-Host "A managed Group Policy or Intune baseline defining this right will override it." -ForegroundColor DarkGray
}
finally {
    foreach ($f in @($export, $db)) {
        if (Test-Path -LiteralPath $f) { Remove-Item -LiteralPath $f -Force -ErrorAction SilentlyContinue }
    }
}
