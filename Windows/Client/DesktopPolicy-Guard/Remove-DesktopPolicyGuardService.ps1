<#
.SYNOPSIS
    Removes the Desktop Policy Guard Windows service.

.DESCRIPTION
    Stops and uninstalls the Desktop Policy Guard service. Optionally removes the
    installed configuration, logs, status data, service wrapper, and scripts.

.PARAMETER InstallDirectory
    Installed service directory.

.PARAMETER RemoveInstalledFiles
    Also removes the installation directory after uninstalling the service.

.EXAMPLE
    .\Remove-DesktopPolicyGuardService.ps1

.EXAMPLE
    .\Remove-DesktopPolicyGuardService.ps1 -RemoveInstalledFiles

.NOTES
    File Name  : Remove-DesktopPolicyGuardService.ps1
    Author     : Joel Cottrell
    Version    : 1.0.0
    Updated    : 2026-11-05
    Requires   : Windows PowerShell 5.1 or later; local administrator

    Repository : https://github.com/joelcottrell/powershell-toolkit
#>

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
param(
    [Parameter()]
    [string]$InstallDirectory = 'C:\ProgramData\DesktopPolicy-Guard',

    [Parameter()]
    [switch]$RemoveInstalledFiles
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ServiceId = 'DesktopPolicyGuard'
$WrapperPath = Join-Path -Path $InstallDirectory -ChildPath "$ServiceId.exe"

$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($identity)

if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw 'Run this uninstaller from an elevated Windows PowerShell session.'
}

$service = Get-Service -Name $ServiceId -ErrorAction SilentlyContinue

if ($null -ne $service) {
    if ($PSCmdlet.ShouldProcess($ServiceId, 'Stop and uninstall Windows service')) {
        if ($service.Status -ne 'Stopped') {
            Stop-Service -Name $ServiceId -Force -ErrorAction Stop
            $service.WaitForStatus('Stopped', [TimeSpan]::FromSeconds(20))
        }

        if (Test-Path -LiteralPath $WrapperPath -PathType Leaf) {
            & $WrapperPath uninstall 2>&1 | ForEach-Object { Write-Host $_ }

            if ($LASTEXITCODE -ne 0) {
                throw "WinSW failed to uninstall the service. Exit code: $LASTEXITCODE"
            }
        }
        else {
            & sc.exe delete $ServiceId | Out-Null
        }

        Write-Host "Uninstalled service: $ServiceId" -ForegroundColor Green
    }
}
else {
    Write-Host "Service is not installed: $ServiceId" -ForegroundColor Yellow
}

if ($RemoveInstalledFiles -and (Test-Path -LiteralPath $InstallDirectory)) {
    if ($PSCmdlet.ShouldProcess($InstallDirectory, 'Remove installed service files, configuration, logs, and status data')) {
        Remove-Item -LiteralPath $InstallDirectory -Recurse -Force
        Write-Host "Removed installation directory: $InstallDirectory" -ForegroundColor Green
    }
}
