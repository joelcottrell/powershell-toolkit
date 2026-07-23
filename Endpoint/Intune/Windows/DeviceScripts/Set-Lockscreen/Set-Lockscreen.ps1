<#
.SYNOPSIS
    Sets the Windows lock screen and desktop background through the Personalization CSP.

.DESCRIPTION
    Configures the lock screen and desktop background under the PersonalizationCSP registry
    key, from either a pair of URLs or a pair of local files. Written for deployment as an
    Intune platform script.

    The Personalization CSP is honoured on Windows Enterprise and Education only. On Windows
    Pro the keys are written but ignored, so the policy appears to apply and does nothing.
    Confirm the edition before relying on this.

.PARAMETER BackgroundUrl
    URL of the desktop background image. Used with the FromUrl parameter set.

.PARAMETER LockscreenUrl
    URL of the lock screen image. Used with the FromUrl parameter set.

.PARAMETER BackgroundPath
    Path to a local desktop background image. Used with the FromFile parameter set.

.PARAMETER LockscreenPath
    Path to a local lock screen image. Used with the FromFile parameter set.

.PARAMETER DestinationFolder
    Where the images are stored on the device. Defaults to C:\ProgramData\Lockscreen.

.EXAMPLE
    .\Set-Lockscreen.ps1 -BackgroundUrl "https://host/bg.jpg" -LockscreenUrl "https://host/lock.jpg"
    Downloads both images and applies them.

.EXAMPLE
    .\Set-Lockscreen.ps1 -BackgroundPath ".\bg.jpg" -LockscreenPath ".\lock.jpg"
    Applies two images shipped alongside the script.

.NOTES
    File Name  : Set-Lockscreen.ps1
    Author     : Joel Cottrell
    Version    : 1.1.0
    Updated    : 2026-07-23
    Requires   : PowerShell 5.1 or later, elevation, Windows Enterprise or Education

    Approach based on:
    https://smbtothecloud.com/set-desktop-lock-screen-background

    Repository : https://github.com/joelcottrell/powershell-toolkit

    ==========================================================================
    REMOTE EXECUTION FROM GITHUB
    ==========================================================================

    Option 2 - Download and run (recommended, allows review before execution):

        $u = "https://raw.githubusercontent.com/joelcottrell/powershell-toolkit/main/Endpoint/Intune/Windows/DeviceScripts/Set-Lockscreen/Set-Lockscreen.ps1"
        $p = "C:\Scripts\Set-Lockscreen.ps1"
        New-Item -Path (Split-Path $p) -ItemType Directory -Force | Out-Null
        Invoke-WebRequest -Uri $u -OutFile $p -UseBasicParsing
        & $p -BackgroundUrl "https://host/bg.jpg" -LockscreenUrl "https://host/lock.jpg"

    For the full remote-execution pattern and its security notes, see any project in this
    repository. For production, pin the URL to a release tag rather than 'main'.

    ==========================================================================
#>

[CmdletBinding(SupportsShouldProcess = $true, DefaultParameterSetName = 'FromUrl')]
param(
    [Parameter(Mandatory = $true, ParameterSetName = 'FromUrl')]
    [ValidateNotNullOrEmpty()]
    [string]$BackgroundUrl,

    [Parameter(Mandatory = $true, ParameterSetName = 'FromUrl')]
    [ValidateNotNullOrEmpty()]
    [string]$LockscreenUrl,

    [Parameter(Mandatory = $true, ParameterSetName = 'FromFile')]
    [ValidateScript({ Test-Path -LiteralPath $_ })]
    [string]$BackgroundPath,

    [Parameter(Mandatory = $true, ParameterSetName = 'FromFile')]
    [ValidateScript({ Test-Path -LiteralPath $_ })]
    [string]$LockscreenPath,

    [string]$DestinationFolder = (Join-Path $env:ProgramData 'Lockscreen')
)

$identity  = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($identity)
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "This script must be run from an elevated PowerShell session."
    exit 1
}

$regPath        = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\PersonalizationCSP'
$backgroundDest = Join-Path $DestinationFolder 'background.jpg'
$lockscreenDest = Join-Path $DestinationFolder 'lockscreen.jpg'

if (-not $PSCmdlet.ShouldProcess($regPath, "Set lock screen and desktop background")) {
    Write-Host "Would apply background and lock screen images to $DestinationFolder." -ForegroundColor DarkYellow
    return
}

if (-not (Test-Path -LiteralPath $DestinationFolder)) {
    New-Item -Path $DestinationFolder -ItemType Directory -Force | Out-Null
}

# Stage the images.
try {
    if ($PSCmdlet.ParameterSetName -eq 'FromUrl') {
        Write-Host "Downloading images..." -ForegroundColor Yellow
        Start-BitsTransfer -Source $BackgroundUrl -Destination $backgroundDest -ErrorAction Stop
        Start-BitsTransfer -Source $LockscreenUrl -Destination $lockscreenDest -ErrorAction Stop
    } else {
        Write-Host "Copying images..." -ForegroundColor Yellow
        Copy-Item -LiteralPath $BackgroundPath -Destination $backgroundDest -Force -ErrorAction Stop
        Copy-Item -LiteralPath $LockscreenPath -Destination $lockscreenDest -Force -ErrorAction Stop
    }
} catch {
    Write-Error "Failed to stage images: $($_.Exception.Message)"
    exit 1
}

if (-not (Test-Path -LiteralPath $regPath)) {
    New-Item -Path $regPath -Force | Out-Null
}

$values = @(
    @{ Name = 'LockScreenImagePath';   Value = $lockscreenDest; Type = 'String' }
    @{ Name = 'LockScreenImageUrl';    Value = $lockscreenDest; Type = 'String' }
    @{ Name = 'LockScreenImageStatus'; Value = 1;               Type = 'DWord'  }
    @{ Name = 'DesktopImagePath';      Value = $backgroundDest; Type = 'String' }
    @{ Name = 'DesktopImageUrl';       Value = $backgroundDest; Type = 'String' }
    @{ Name = 'DesktopImageStatus';    Value = 1;               Type = 'DWord'  }
)

foreach ($v in $values) {
    New-ItemProperty -Path $regPath -Name $v.Name -Value $v.Value -PropertyType $v.Type -Force | Out-Null
}

Write-Host "[OK] Lock screen and desktop background applied." -ForegroundColor Green
Write-Host "The Personalization CSP is honoured on Enterprise/Education only." -ForegroundColor DarkGray
