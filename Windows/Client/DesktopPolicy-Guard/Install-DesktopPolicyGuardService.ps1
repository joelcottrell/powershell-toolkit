<#
.SYNOPSIS
    Installs Desktop Policy Guard as a Windows service using WinSW.

.DESCRIPTION
    Validates elevation and package files, stages the service engine and
    configuration under ProgramData, downloads or accepts a pinned WinSW x64
    wrapper, installs the service as LocalSystem with delayed automatic start,
    starts it, and validates the service heartbeat.

    The installer does not commit or bundle WinSW in the repository. It downloads
    the pinned release at installation time unless -WinSWSourcePath is supplied.

.PARAMETER InstallDirectory
    Service installation directory. Defaults to C:\ProgramData\DesktopPolicy-Guard.

.PARAMETER WinSWSourcePath
    Optional path to an existing WinSW-x64.exe for environments without GitHub
    download access.

.EXAMPLE
    .\Install-DesktopPolicyGuardService.ps1

.EXAMPLE
    .\Install-DesktopPolicyGuardService.ps1 -WinSWSourcePath C:\Tools\WinSW-x64.exe

.EXAMPLE
    .\Install-DesktopPolicyGuardService.ps1 -WhatIf

.NOTES
    File Name  : Install-DesktopPolicyGuardService.ps1
    Author     : Joel Cottrell
    Version    : 1.0.0
    Updated    : 2026-11-05
    Requires   : Windows PowerShell 5.1 or later; local administrator

    Repository : https://github.com/joelcottrell/powershell-toolkit

    ==========================================================================
    REMOTE EXECUTION FROM GITHUB
    ==========================================================================

    Option 1 - Run directly without downloading:

        $u = "https://raw.githubusercontent.com/joelcottrell/powershell-toolkit/main/Windows/Client/DesktopPolicy-Guard/Install-DesktopPolicyGuardService.ps1"
        Invoke-Expression (Invoke-WebRequest -Uri $u -UseBasicParsing).Content

    Option 2 - Download and run (recommended, allows review before execution):

        $u = "https://raw.githubusercontent.com/joelcottrell/powershell-toolkit/main/Windows/Client/DesktopPolicy-Guard/Install-DesktopPolicyGuardService.ps1"
        $p = "C:\Scripts\Install-DesktopPolicyGuardService.ps1"
        New-Item -Path (Split-Path $p) -ItemType Directory -Force | Out-Null
        Invoke-WebRequest -Uri $u -OutFile $p -UseBasicParsing
        & $p

    SECURITY: Direct remote execution does not allow code review first. Download,
    review, and pin production use to a release tag instead of main.
    ==========================================================================

#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter()]
    [string]$InstallDirectory = 'C:\ProgramData\DesktopPolicy-Guard',

    [Parameter()]
    [string]$WinSWSourcePath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ServiceId = 'DesktopPolicyGuard'
$ServiceName = 'Desktop Policy Guard'
$WinSWVersion = '2.12.0'
$WinSWDownloadUrl = 'https://github.com/winsw/winsw/releases/download/v2.12.0/WinSW-x64.exe'
$ExpectedWinSWSize = 18243033

$SourceServiceScript = Join-Path -Path $PSScriptRoot -ChildPath 'Start-DesktopPolicyGuard.ps1'
$SourceConfig = Join-Path -Path $PSScriptRoot -ChildPath 'Config\config.example.json'
$BundledWinSW = Join-Path -Path $PSScriptRoot -ChildPath 'WinSW-x64.exe'

$InstalledServiceScript = Join-Path -Path $InstallDirectory -ChildPath 'Start-DesktopPolicyGuard.ps1'
$InstalledConfig = Join-Path -Path $InstallDirectory -ChildPath 'config.json'
$WrapperPath = Join-Path -Path $InstallDirectory -ChildPath "$ServiceId.exe"
$WrapperConfigPath = Join-Path -Path $InstallDirectory -ChildPath "$ServiceId.xml"
$StatusFile = Join-Path -Path $InstallDirectory -ChildPath 'Status\status.json'

function Test-IsAdministrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Write-InstallStatus {
    param(
        [Parameter(Mandatory)]
        [ValidateSet('Info', 'Success', 'Warning')]
        [string]$Type,

        [Parameter(Mandatory)]
        [string]$Message
    )

    $color = switch ($Type) {
        'Success' { 'Green' }
        'Warning' { 'Yellow' }
        default   { 'Cyan' }
    }

    Write-Host "[$Type] $Message" -ForegroundColor $color
}

function Stop-AndRemoveExistingService {
    $existing = Get-Service -Name $ServiceId -ErrorAction SilentlyContinue

    if ($null -eq $existing) {
        return
    }

    Write-InstallStatus -Type 'Warning' -Message "Existing service detected: $ServiceName"

    if ($existing.Status -ne 'Stopped') {
        Stop-Service -Name $ServiceId -Force -ErrorAction Stop
        $existing.WaitForStatus('Stopped', [TimeSpan]::FromSeconds(20))
    }

    if (Test-Path -LiteralPath $WrapperPath) {
        & $WrapperPath uninstall 2>&1 | ForEach-Object { Write-Host $_ }

        if ($LASTEXITCODE -ne 0) {
            throw "WinSW failed to uninstall the existing service. Exit code: $LASTEXITCODE"
        }
    }
    else {
        & sc.exe delete $ServiceId | Out-Null
    }

    for ($i = 0; $i -lt 20; $i++) {
        if ($null -eq (Get-Service -Name $ServiceId -ErrorAction SilentlyContinue)) {
            break
        }

        Start-Sleep -Seconds 1
    }

    if ($null -ne (Get-Service -Name $ServiceId -ErrorAction SilentlyContinue)) {
        throw "Existing service '$ServiceId' could not be removed."
    }
}

function Get-WinSWBinary {
    param(
        [Parameter(Mandatory)]
        [string]$Destination
    )

    $selectedSource = $null

    if (-not [string]::IsNullOrWhiteSpace($WinSWSourcePath)) {
        if (-not (Test-Path -LiteralPath $WinSWSourcePath -PathType Leaf)) {
            throw "WinSWSourcePath does not exist: $WinSWSourcePath"
        }

        $selectedSource = $WinSWSourcePath
        Write-InstallStatus -Type 'Info' -Message 'Using WinSW supplied with -WinSWSourcePath.'
    }
    elseif (Test-Path -LiteralPath $BundledWinSW -PathType Leaf) {
        $selectedSource = $BundledWinSW
        Write-InstallStatus -Type 'Info' -Message 'Using WinSW-x64.exe from the package directory.'
    }

    if ($null -ne $selectedSource) {
        Copy-Item -LiteralPath $selectedSource -Destination $Destination -Force
    }
    else {
        Write-InstallStatus -Type 'Info' -Message "Downloading WinSW $WinSWVersion x64 from the official WinSW GitHub release."
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

        Invoke-WebRequest `
            -Uri $WinSWDownloadUrl `
            -OutFile $Destination `
            -UseBasicParsing `
            -ErrorAction Stop
    }

    $downloadedFile = Get-Item -LiteralPath $Destination -ErrorAction Stop

    if ($downloadedFile.Length -ne $ExpectedWinSWSize) {
        Remove-Item -LiteralPath $Destination -Force -ErrorAction SilentlyContinue
        throw "WinSW binary size validation failed. Expected $ExpectedWinSWSize bytes but received $($downloadedFile.Length) bytes."
    }

    Unblock-File -LiteralPath $Destination -ErrorAction SilentlyContinue
    Write-InstallStatus -Type 'Success' -Message "WinSW $WinSWVersion staged successfully."
}

if (-not (Test-IsAdministrator)) {
    throw 'Run this installer from an elevated Windows PowerShell session.'
}

foreach ($requiredFile in @($SourceServiceScript, $SourceConfig)) {
    if (-not (Test-Path -LiteralPath $requiredFile -PathType Leaf)) {
        throw "Required package file not found: $requiredFile"
    }
}

Write-InstallStatus -Type 'Info' -Message 'Beginning Desktop Policy Guard service installation.'

if (-not $PSCmdlet.ShouldProcess($InstallDirectory, "Install and start the '$ServiceName' Windows service")) {
    return
}

New-Item -Path $InstallDirectory -ItemType Directory -Force | Out-Null
New-Item -Path (Join-Path -Path $InstallDirectory -ChildPath 'Logs') -ItemType Directory -Force | Out-Null
New-Item -Path (Join-Path -Path $InstallDirectory -ChildPath 'Status') -ItemType Directory -Force | Out-Null

Stop-AndRemoveExistingService

Copy-Item -LiteralPath $SourceServiceScript -Destination $InstalledServiceScript -Force

if (-not (Test-Path -LiteralPath $InstalledConfig -PathType Leaf)) {
    Copy-Item -LiteralPath $SourceConfig -Destination $InstalledConfig -Force
    Write-InstallStatus -Type 'Success' -Message "Created initial configuration: $InstalledConfig"
}
else {
    Write-InstallStatus -Type 'Info' -Message "Preserving existing configuration: $InstalledConfig"
}

Unblock-File -LiteralPath $InstalledServiceScript -ErrorAction SilentlyContinue
Get-WinSWBinary -Destination $WrapperPath

$wrapperXml = @"
<service>
  <id>$ServiceId</id>
  <name>$ServiceName</name>
  <description>Continuously enforces configured Windows policy values and desktop shortcut settings without an interactive PowerShell window.</description>
  <executable>%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe</executable>
  <arguments>-NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "%BASE%\Start-DesktopPolicyGuard.ps1" -ConfigPath "%BASE%\config.json"</arguments>
  <workingdirectory>%BASE%</workingdirectory>
  <startmode>Automatic</startmode>
  <delayedAutoStart>true</delayedAutoStart>
  <serviceaccount>
    <username>LocalSystem</username>
  </serviceaccount>
  <onfailure action="restart" delay="10 sec"/>
  <resetfailure>1 hour</resetfailure>
  <log mode="roll"></log>
</service>
"@

Set-Content -LiteralPath $WrapperConfigPath -Value $wrapperXml -Encoding UTF8

Write-InstallStatus -Type 'Info' -Message "Installing Windows service '$ServiceName'."
& $WrapperPath install 2>&1 | ForEach-Object { Write-Host $_ }

if ($LASTEXITCODE -ne 0) {
    throw "WinSW service installation failed. Exit code: $LASTEXITCODE"
}

& $WrapperPath start 2>&1 | ForEach-Object { Write-Host $_ }

if ($LASTEXITCODE -ne 0) {
    throw "WinSW failed to start the service. Exit code: $LASTEXITCODE"
}

$serviceReady = $false

for ($i = 0; $i -lt 30; $i++) {
    $service = Get-Service -Name $ServiceId -ErrorAction SilentlyContinue

    if ($null -ne $service -and $service.Status -eq 'Running' -and (Test-Path -LiteralPath $StatusFile -PathType Leaf)) {
        $serviceReady = $true
        break
    }

    Start-Sleep -Seconds 1
}

if (-not $serviceReady) {
    throw 'The service was installed but did not reach a validated running state.'
}

$status = Get-Content -LiteralPath $StatusFile -Raw | ConvertFrom-Json

Write-InstallStatus -Type 'Success' -Message 'Service is running and produced a status heartbeat.'
Write-Host ("Service              : {0}" -f $ServiceName)
Write-Host ("Service ID           : {0}" -f $ServiceId)
Write-Host ("Run As               : LocalSystem")
Write-Host ("Install Directory    : {0}" -f $InstallDirectory)
Write-Host ("Last Pass            : {0}" -f $status.PassCompleted)
Write-Host ("Last Successful Pass : {0}" -f $status.LastSuccessfulPass)
Write-Host ("Loaded Users         : {0}" -f $status.LoadedUserCount)
Write-Host ("Findings             : {0}" -f $status.Findings)
Write-Host ("Corrections          : {0}" -f $status.Corrections)
Write-Host ("Errors               : {0}" -f $status.Errors)
Write-InstallStatus -Type 'Success' -Message 'Desktop Policy Guard service installation is complete.'
