<#
.SYNOPSIS
    Detection rule for the lock screen and desktop background policy.

.DESCRIPTION
    Reports whether all six PersonalizationCSP values are present and set to the expected
    paths and enabled status. Intended as an Intune Win32 app or remediation detection
    script: exit 0 and "Detected" when compliant, exit 1 otherwise.

    Compliance means the two status values are 1 (enabled) and the four path/URL values all
    point at the expected image locations under the destination folder.

.PARAMETER DestinationFolder
    The folder the images were staged to by Set-Lockscreen.ps1. Must match what was used
    there. Defaults to C:\ProgramData\Lockscreen.

.EXAMPLE
    .\Test-Lockscreen.ps1
    Writes "Detected" and exits 0 when the policy is fully applied.

.NOTES
    File Name  : Test-Lockscreen.ps1
    Author     : Joel Cottrell
    Version    : 1.1.0
    Updated    : 2026-07-23
    Requires   : PowerShell 5.1 or later

    Repository : https://github.com/joelcottrell/powershell-toolkit

    For the full remote-execution pattern and its security notes, see any project in this
    repository. For production, pin the URL to a release tag rather than 'main'.
#>

[CmdletBinding()]
param(
    [string]$DestinationFolder = (Join-Path $env:ProgramData 'Lockscreen')
)

$regPath        = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\PersonalizationCSP'
$backgroundPath = Join-Path $DestinationFolder 'background.jpg'
$lockscreenPath = Join-Path $DestinationFolder 'lockscreen.jpg'

function Get-CspValue {
    param([string]$Name)
    return (Get-ItemProperty -Path $regPath -Name $Name -ErrorAction SilentlyContinue).$Name
}

# Every expected value paired with what it should be. The original detection script
# chained these with a precedence bug ($a -and $b -eq $x), which does not compare $a to
# anything. Each condition is now evaluated explicitly.
$expected = @(
    @{ Name = 'DesktopImageStatus';    Expected = 1 }
    @{ Name = 'LockScreenImageStatus'; Expected = 1 }
    @{ Name = 'DesktopImagePath';      Expected = $backgroundPath }
    @{ Name = 'DesktopImageUrl';       Expected = $backgroundPath }
    @{ Name = 'LockScreenImagePath';   Expected = $lockscreenPath }
    @{ Name = 'LockScreenImageUrl';    Expected = $lockscreenPath }
)

$compliant = $true
foreach ($item in $expected) {
    $actual = Get-CspValue -Name $item.Name
    if ($actual -ne $item.Expected) {
        $compliant = $false
        break
    }
}

if ($compliant -and (Test-Path -LiteralPath $backgroundPath) -and (Test-Path -LiteralPath $lockscreenPath)) {
    Write-Output "Detected"
    exit 0
}

Write-Output "Lock screen policy is missing values or images are absent."
exit 1
