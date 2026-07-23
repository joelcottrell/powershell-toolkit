<#
.SYNOPSIS
    One-line description of what the script does.

.DESCRIPTION
    Fuller explanation covering what problem it solves, what it changes, and what
    it deliberately does not do.

    The last part matters most. Stating the boundary stops the next person
    assuming the script does more than it does.

.PARAMETER ParameterName
    Description of each parameter.

.EXAMPLE
    .\Verb-Noun.ps1 -ParameterName "value"
    Describes what this invocation does.

.NOTES
    File Name  : Verb-Noun.ps1
    Author     : Joel Cottrell
    Version    : 1.0.0
    Updated    : YYYY-MM-DD
    Requires   : PowerShell 5.1 or later, <module names>

    Repository : https://github.com/joelcottrell/powershell-toolkit

    ==========================================================================
    REMOTE EXECUTION FROM GITHUB
    ==========================================================================

    Option 1 - Run directly without downloading:

        $u = "https://raw.githubusercontent.com/joelcottrell/powershell-toolkit/main/<Domain>/<Technology>/<Project>/Verb-Noun.ps1"
        Invoke-Expression (Invoke-WebRequest -Uri $u -UseBasicParsing).Content

    Option 2 - Download and run (recommended, allows review before execution):

        $u = "https://raw.githubusercontent.com/joelcottrell/powershell-toolkit/main/<Domain>/<Technology>/<Project>/Verb-Noun.ps1"
        $p = "C:\Scripts\Verb-Noun.ps1"
        New-Item -Path (Split-Path $p) -ItemType Directory -Force | Out-Null
        Invoke-WebRequest -Uri $u -OutFile $p -UseBasicParsing
        & $p

    Option 3 - Scheduled task (refreshes the script on each run):

        $u = "https://raw.githubusercontent.com/joelcottrell/powershell-toolkit/main/<Domain>/<Technology>/<Project>/Verb-Noun.ps1"
        $p = "C:\Scripts\Verb-Noun.ps1"
        $cmd = "Invoke-WebRequest -Uri '$u' -OutFile '$p' -UseBasicParsing; & '$p'"
        $act = New-ScheduledTaskAction -Execute "powershell.exe" `
                   -Argument "-NoProfile -ExecutionPolicy Bypass -Command `"$cmd`""
        $trg = New-ScheduledTaskTrigger -Daily -At 3am
        Register-ScheduledTask -TaskName "Verb-Noun" -Action $act -Trigger $trg `
                   -RunLevel Highest -User "SYSTEM"

    SECURITY: Option 1 executes remote code without review. Option 3 re-downloads
    on every run, so a compromised repository propagates immediately. Option 2 is
    the default recommendation. For anything touching production, replace 'main'
    with a release tag so the code cannot change under you.

    ==========================================================================
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $true)]
    [string]$ParameterName
)

# ---------------------------------------------------------------------------
# Script body
# ---------------------------------------------------------------------------

Write-Verbose "Starting $($MyInvocation.MyCommand.Name)"

# Your logic here. Prefer -WhatIf support on anything that writes.

Write-Verbose "Completed $($MyInvocation.MyCommand.Name)"
