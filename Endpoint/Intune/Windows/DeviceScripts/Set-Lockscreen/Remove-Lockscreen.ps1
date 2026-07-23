<#
.SYNOPSIS
    Removes the lock screen and desktop background values set through the Personalization CSP.

.DESCRIPTION
    Deletes the six PersonalizationCSP registry values that Set-Lockscreen.ps1 writes,
    reverting the device to its default lock screen and desktop background. Missing values
    are ignored, so this is safe to run whether or not the policy was applied.

    This removes the registry configuration. It does not delete the staged image files under
    the destination folder, and it does not restore any previous custom wallpaper - the
    device falls back to the Windows default.

.EXAMPLE
    .\Remove-Lockscreen.ps1
    Reverts the lock screen and desktop background policy.

.EXAMPLE
    .\Remove-Lockscreen.ps1 -WhatIf
    Shows which values would be removed without changing anything.

.NOTES
    File Name  : Remove-Lockscreen.ps1
    Author     : Joel Cottrell
    Version    : 1.1.0
    Updated    : 2026-07-23
    Requires   : PowerShell 5.1 or later, elevation

    Repository : https://github.com/joelcottrell/powershell-toolkit

    For the full remote-execution pattern and its security notes, see any project in this
    repository. For production, pin the URL to a release tag rather than 'main'.
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param()

$identity  = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($identity)
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "This script must be run from an elevated PowerShell session."
    exit 1
}

$regPath = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\PersonalizationCSP'
$names   = @(
    'LockScreenImagePath', 'LockScreenImageUrl', 'LockScreenImageStatus',
    'DesktopImagePath',    'DesktopImageUrl',    'DesktopImageStatus'
)

if (-not (Test-Path -LiteralPath $regPath)) {
    Write-Host "PersonalizationCSP key not present. Nothing to remove." -ForegroundColor DarkGray
    return
}

foreach ($name in $names) {
    $exists = Get-ItemProperty -Path $regPath -Name $name -ErrorAction SilentlyContinue
    if ($null -eq $exists) {
        Write-Host "  $name not set. Skipping." -ForegroundColor DarkGray
        continue
    }
    if ($PSCmdlet.ShouldProcess("$regPath\$name", 'Remove value')) {
        Remove-ItemProperty -Path $regPath -Name $name -Force -ErrorAction SilentlyContinue
        Write-Host "  Removed $name" -ForegroundColor DarkGray
    }
}

Write-Host "[OK] Lock screen and desktop background policy reverted." -ForegroundColor Green
