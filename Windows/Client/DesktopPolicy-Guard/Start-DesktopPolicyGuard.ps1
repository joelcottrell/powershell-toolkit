<#
.SYNOPSIS
    Continuously enforces configured Windows registry values and desktop
    shortcut cleanup as a background service workload.

.DESCRIPTION
    Runs behind a Windows service wrapper under LocalSystem. Each pass validates
    configured machine registry values, enumerates loaded user hives under
    HKEY_USERS, enforces configured user registry values, removes configured
    shortcuts, writes rotating logs, and updates a JSON status heartbeat.

    -RunOnce performs a single pass and exits.
    -AuditOnly reports drift without making changes.

    This script does not install the service wrapper. Use
    Install-DesktopPolicyGuardService.ps1 for installation.

.PARAMETER ConfigPath
    Path to the JSON configuration file. Defaults to config.json beside the
    installed script.

.PARAMETER RunOnce
    Performs one enforcement pass and exits.

.PARAMETER AuditOnly
    Reports findings without modifying registry values or removing shortcuts.

.EXAMPLE
    .\Start-DesktopPolicyGuard.ps1 -RunOnce -AuditOnly

.EXAMPLE
    .\Start-DesktopPolicyGuard.ps1 -ConfigPath .\Config\config.example.json

.NOTES
    File Name  : Start-DesktopPolicyGuard.ps1
    Author     : Joel Cottrell
    Version    : 1.0.0
    Updated    : 2026-11-05
    Requires   : Windows PowerShell 5.1 or later

    Repository : https://github.com/joelcottrell/powershell-toolkit

    ==========================================================================
    REMOTE EXECUTION FROM GITHUB
    ==========================================================================

    Option 1 - Run directly without downloading:

        $u = "https://raw.githubusercontent.com/joelcottrell/powershell-toolkit/main/Windows/Client/DesktopPolicy-Guard/Start-DesktopPolicyGuard.ps1"
        Invoke-Expression (Invoke-WebRequest -Uri $u -UseBasicParsing).Content

    Option 2 - Download and run (recommended, allows review before execution):

        $u = "https://raw.githubusercontent.com/joelcottrell/powershell-toolkit/main/Windows/Client/DesktopPolicy-Guard/Start-DesktopPolicyGuard.ps1"
        $p = "C:\Scripts\Start-DesktopPolicyGuard.ps1"
        New-Item -Path (Split-Path $p) -ItemType Directory -Force | Out-Null
        Invoke-WebRequest -Uri $u -OutFile $p -UseBasicParsing
        & $p

    SECURITY: Direct remote execution does not allow code review first. Download,
    review, and pin production use to a release tag instead of main.
    ==========================================================================

#>

[CmdletBinding()]
param(
    [Parameter()]
    [string]$ConfigPath = (Join-Path -Path $PSScriptRoot -ChildPath 'config.json'),

    [Parameter()]
    [switch]$RunOnce,

    [Parameter()]
    [switch]$AuditOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$Script:PassCorrections = 0
$Script:PassFindings = 0
$Script:PassErrors = 0
$Script:LastSuccessfulPass = $null

$InstallRoot = $PSScriptRoot
$LogDirectory = Join-Path -Path $InstallRoot -ChildPath 'Logs'
$StatusFile = Join-Path -Path $InstallRoot -ChildPath 'Status\status.json'
$LogFile = Join-Path -Path $LogDirectory -ChildPath 'DesktopPolicyGuard.log'

function Import-GuardConfiguration {
    if (-not (Test-Path -LiteralPath $ConfigPath -PathType Leaf)) {
        throw "Configuration file not found: $ConfigPath"
    }

    $raw = Get-Content -LiteralPath $ConfigPath -Raw -ErrorAction Stop
    $configuration = $raw | ConvertFrom-Json -ErrorAction Stop

    if ($null -eq $configuration.CheckIntervalSeconds) {
        throw 'CheckIntervalSeconds is missing from config.json.'
    }

    if ([int]$configuration.CheckIntervalSeconds -lt 5) {
        throw 'CheckIntervalSeconds must be at least 5 seconds.'
    }

    return $configuration
}

$Config = Import-GuardConfiguration

function Initialize-GuardDirectories {
    foreach ($path in @(
        $LogDirectory,
        (Split-Path -Path $StatusFile -Parent)
    )) {
        if (-not (Test-Path -LiteralPath $path)) {
            New-Item -Path $path -ItemType Directory -Force | Out-Null
        }
    }
}

function Invoke-LogRotation {
    if (-not (Test-Path -LiteralPath $LogFile)) {
        return
    }

    $maximumBytes = [int]$Config.LogMaxSizeMB * 1MB
    if ($maximumBytes -le 0) {
        $maximumBytes = 5MB
    }

    $currentSize = (Get-Item -LiteralPath $LogFile).Length
    if ($currentSize -lt $maximumBytes) {
        return
    }

    $archiveDirectory = Join-Path -Path $LogDirectory -ChildPath 'Archive'
    if (-not (Test-Path -LiteralPath $archiveDirectory)) {
        New-Item -Path $archiveDirectory -ItemType Directory -Force | Out-Null
    }

    $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $archiveFile = Join-Path -Path $archiveDirectory -ChildPath "DesktopPolicyGuard-$timestamp.log"
    Move-Item -LiteralPath $LogFile -Destination $archiveFile -Force

    $retention = [int]$Config.LogRetentionCount
    if ($retention -lt 1) {
        $retention = 10
    }

    Get-ChildItem -LiteralPath $archiveDirectory -Filter 'DesktopPolicyGuard-*.log' -File |
        Sort-Object -Property LastWriteTime -Descending |
        Select-Object -Skip $retention |
        Remove-Item -Force -ErrorAction SilentlyContinue
}

function Write-GuardLog {
    param(
        [Parameter(Mandatory)]
        [ValidateSet('INFO', 'SUCCESS', 'WARNING', 'ERROR', 'AUDIT')]
        [string]$Level,

        [Parameter(Mandatory)]
        [string]$Message
    )

    Initialize-GuardDirectories
    Invoke-LogRotation

    $entry = '{0} [{1}] [{2}] {3}' -f (
        Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    ), $env:COMPUTERNAME, $Level, $Message

    Add-Content -LiteralPath $LogFile -Value $entry -Encoding UTF8
}

function Get-RegistryValueState {
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [string]$Name
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        return [pscustomobject]@{
            PathExists  = $false
            ValueExists = $false
            Value       = $null
            ValueKind   = $null
        }
    }

    $key = Get-Item -LiteralPath $Path -ErrorAction Stop
    $valueExists = $key.GetValueNames() -contains $Name

    if (-not $valueExists) {
        return [pscustomobject]@{
            PathExists  = $true
            ValueExists = $false
            Value       = $null
            ValueKind   = $null
        }
    }

    return [pscustomobject]@{
        PathExists  = $true
        ValueExists = $true
        Value       = $key.GetValue(
            $Name,
            $null,
            [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames
        )
        ValueKind   = $key.GetValueKind($Name)
    }
}

function Set-DesiredDword {
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [int]$Value,

        [Parameter(Mandatory)]
        [string]$Context
    )

    try {
        $state = Get-RegistryValueState -Path $Path -Name $Name

        $requiresCorrection =
            (-not $state.PathExists) -or
            (-not $state.ValueExists) -or
            ($state.ValueKind -ne [Microsoft.Win32.RegistryValueKind]::DWord) -or
            ([int]$state.Value -ne $Value)

        if (-not $requiresCorrection) {
            return
        }

        $Script:PassFindings++

        $previousState = if (-not $state.PathExists) {
            'registry path missing'
        }
        elseif (-not $state.ValueExists) {
            'value missing'
        }
        else {
            "value '$($state.Value)' type '$($state.ValueKind)'"
        }

        if ($AuditOnly) {
            Write-GuardLog -Level 'AUDIT' -Message "[$Context] $Path\$Name is $previousState; desired REG_DWORD=$Value."
            return
        }

        if (-not (Test-Path -LiteralPath $Path)) {
            New-Item -Path $Path -Force -ErrorAction Stop | Out-Null
        }

        New-ItemProperty `
            -LiteralPath $Path `
            -Name $Name `
            -PropertyType DWord `
            -Value $Value `
            -Force `
            -ErrorAction Stop |
            Out-Null

        $verified = Get-RegistryValueState -Path $Path -Name $Name

        if (
            (-not $verified.ValueExists) -or
            ($verified.ValueKind -ne [Microsoft.Win32.RegistryValueKind]::DWord) -or
            ([int]$verified.Value -ne $Value)
        ) {
            throw 'Post-write verification failed.'
        }

        $Script:PassCorrections++
        Write-GuardLog -Level 'SUCCESS' -Message "[$Context] Corrected $Path\$Name to REG_DWORD=$Value."
    }
    catch {
        $Script:PassErrors++
        Write-GuardLog -Level 'ERROR' -Message "[$Context] Failed to enforce $Path\$Name. $($_.Exception.Message)"
    }
}

function Get-LoadedUserProfiles {
    $profileListPath = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList'
    $results = @()

    foreach ($profileKey in Get-ChildItem -LiteralPath $profileListPath -ErrorAction SilentlyContinue) {
        $sid = $profileKey.PSChildName

        if ($sid -notmatch '^S-1-(5-21|12-1)-') {
            continue
        }

        $userHive = "Registry::HKEY_USERS\$sid"

        if (-not (Test-Path -LiteralPath $userHive)) {
            continue
        }

        $profilePath = (Get-ItemProperty -LiteralPath $profileKey.PSPath -Name 'ProfileImagePath' -ErrorAction SilentlyContinue).ProfileImagePath

        if ([string]::IsNullOrWhiteSpace($profilePath)) {
            continue
        }

        $profilePath = [Environment]::ExpandEnvironmentVariables($profilePath)

        $results += [pscustomobject]@{
            SID         = $sid
            ProfilePath = $profilePath
        }
    }

    return $results
}

function Get-UserEnvironmentMap {
    param(
        [Parameter(Mandatory)]
        [string]$SID,

        [Parameter(Mandatory)]
        [string]$ProfilePath
    )

    $map = @{}

    foreach ($entry in [Environment]::GetEnvironmentVariables('Machine').GetEnumerator()) {
        $map[[string]$entry.Key] = [string]$entry.Value
    }

    $map['USERPROFILE'] = $ProfilePath

    try {
        $profileRoot = [System.IO.Path]::GetPathRoot($ProfilePath)

        if (-not [string]::IsNullOrWhiteSpace($profileRoot)) {
            $map['HOMEDRIVE'] = $profileRoot.TrimEnd('\')
            $map['HOMEPATH'] = $ProfilePath.Substring($profileRoot.Length - 1)
        }
    }
    catch {
    }

    $userEnvironmentPath = "Registry::HKEY_USERS\$SID\Environment"

    if (Test-Path -LiteralPath $userEnvironmentPath) {
        $environmentKey = Get-Item -LiteralPath $userEnvironmentPath -ErrorAction SilentlyContinue

        if ($null -ne $environmentKey) {
            foreach ($name in $environmentKey.GetValueNames()) {
                $value = $environmentKey.GetValue(
                    $name,
                    $null,
                    [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames
                )

                if ($null -ne $value) {
                    $map[$name] = [string]$value
                }
            }
        }
    }

    return $map
}

function Expand-UserPath {
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [hashtable]$EnvironmentMap
    )

    $resolved = $Path

    for ($iteration = 0; $iteration -lt 3; $iteration++) {
        $before = $resolved

        $resolved = [regex]::Replace(
            $resolved,
            '%([^%]+)%',
            {
                param($match)

                $name = $match.Groups[1].Value

                foreach ($key in $EnvironmentMap.Keys) {
                    if ($key -ieq $name) {
                        return [string]$EnvironmentMap[$key]
                    }
                }

                return $match.Value
            }
        )

        if ($resolved -eq $before) {
            break
        }
    }

    return $resolved
}

function Get-UserDesktopPath {
    param(
        [Parameter(Mandatory)]
        [string]$SID,

        [Parameter(Mandatory)]
        [string]$ProfilePath
    )

    $fallback = Join-Path -Path $ProfilePath -ChildPath 'Desktop'
    $shellFolderPath = "Registry::HKEY_USERS\$SID\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders"

    if (-not (Test-Path -LiteralPath $shellFolderPath)) {
        return $fallback
    }

    try {
        $shellFolderKey = Get-Item -LiteralPath $shellFolderPath -ErrorAction Stop

        $rawDesktop = $shellFolderKey.GetValue(
            'Desktop',
            $null,
            [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames
        )

        if ([string]::IsNullOrWhiteSpace([string]$rawDesktop)) {
            return $fallback
        }

        $environmentMap = Get-UserEnvironmentMap -SID $SID -ProfilePath $ProfilePath
        $resolved = Expand-UserPath -Path ([string]$rawDesktop) -EnvironmentMap $environmentMap

        if ($resolved -match '%[^%]+%') {
            Write-GuardLog -Level 'WARNING' -Message "[$SID] Desktop path contains unresolved environment variables: $resolved. Falling back to $fallback."
            return $fallback
        }

        return $resolved
    }
    catch {
        Write-GuardLog -Level 'WARNING' -Message "[$SID] Unable to resolve Desktop path. Using $fallback. $($_.Exception.Message)"
        return $fallback
    }
}

function Remove-ConfiguredShortcut {
    param(
        [Parameter(Mandatory)]
        [string]$ShortcutPath,

        [Parameter(Mandatory)]
        [string]$Context
    )

    if (-not (Test-Path -LiteralPath $ShortcutPath -PathType Leaf)) {
        return
    }

    $Script:PassFindings++

    if ($AuditOnly) {
        Write-GuardLog -Level 'AUDIT' -Message "[$Context] Shortcut exists and would be removed: $ShortcutPath"
        return
    }

    try {
        Remove-Item -LiteralPath $ShortcutPath -Force -ErrorAction Stop
        $Script:PassCorrections++
        Write-GuardLog -Level 'SUCCESS' -Message "[$Context] Removed shortcut: $ShortcutPath"
    }
    catch {
        $Script:PassErrors++
        Write-GuardLog -Level 'ERROR' -Message "[$Context] Failed to remove shortcut '$ShortcutPath'. $($_.Exception.Message)"
    }
}

function Invoke-ShortcutCleanup {
    param(
        [Parameter(Mandatory)]
        [object[]]$LoadedProfiles
    )

    if (-not [bool]$Config.RemoveShortcuts) {
        return
    }

    $publicDesktop = Join-Path -Path $env:PUBLIC -ChildPath 'Desktop'

    foreach ($shortcutName in $Config.ShortcutNames) {
        Remove-ConfiguredShortcut `
            -ShortcutPath (Join-Path -Path $publicDesktop -ChildPath $shortcutName) `
            -Context 'Public Desktop'
    }

    foreach ($profile in $LoadedProfiles) {
        $desktopPath = Get-UserDesktopPath -SID $profile.SID -ProfilePath $profile.ProfilePath

        foreach ($shortcutName in $Config.ShortcutNames) {
            Remove-ConfiguredShortcut `
                -ShortcutPath (Join-Path -Path $desktopPath -ChildPath $shortcutName) `
                -Context "User $($profile.SID)"
        }
    }
}

function Invoke-RegistryEnforcement {
    param(
        [Parameter(Mandatory)]
        [object[]]$LoadedProfiles
    )

    foreach ($entry in $Config.MachineRegistry) {
        if ([string]$entry.Type -ine 'DWord') {
            $Script:PassErrors++
            Write-GuardLog -Level 'ERROR' -Message "Unsupported machine registry type '$($entry.Type)' for $($entry.Path)\$($entry.Name)."
            continue
        }

        Set-DesiredDword `
            -Path ([string]$entry.Path) `
            -Name ([string]$entry.Name) `
            -Value ([int]$entry.Value) `
            -Context 'Machine'
    }

    foreach ($profile in $LoadedProfiles) {
        foreach ($entry in $Config.UserRegistry) {
            if ([string]$entry.Type -ine 'DWord') {
                $Script:PassErrors++
                Write-GuardLog -Level 'ERROR' -Message "Unsupported user registry type '$($entry.Type)' for $($entry.RelativePath)\$($entry.Name)."
                continue
            }

            $path = "Registry::HKEY_USERS\$($profile.SID)\$($entry.RelativePath)"

            Set-DesiredDword `
                -Path $path `
                -Name ([string]$entry.Name) `
                -Value ([int]$entry.Value) `
                -Context "User $($profile.SID)"
        }
    }
}

function Write-StatusFile {
    param(
        [Parameter(Mandatory)]
        [object[]]$LoadedProfiles,

        [Parameter(Mandatory)]
        [datetime]$PassStarted,

        [Parameter(Mandatory)]
        [datetime]$PassCompleted
    )

    if ($Script:PassErrors -eq 0) {
        $Script:LastSuccessfulPass = $PassCompleted
    }

    $status = [ordered]@{
        ComputerName       = $env:COMPUTERNAME
        ProcessId          = $PID
        AuditOnly          = [bool]$AuditOnly
        PassStarted        = $PassStarted.ToString('o')
        PassCompleted      = $PassCompleted.ToString('o')
        LastSuccessfulPass = if ($null -ne $Script:LastSuccessfulPass) { $Script:LastSuccessfulPass.ToString('o') } else { $null }
        LoadedUserCount    = @($LoadedProfiles).Count
        LoadedUsers        = @($LoadedProfiles | ForEach-Object {
            [ordered]@{
                SID         = $_.SID
                ProfilePath = $_.ProfilePath
            }
        })
        Findings           = $Script:PassFindings
        Corrections        = $Script:PassCorrections
        Errors             = $Script:PassErrors
        CheckInterval      = [int]$Config.CheckIntervalSeconds
        Version            = '1.0.0'
    }

    $statusDirectory = Split-Path -Path $StatusFile -Parent

    if (-not (Test-Path -LiteralPath $statusDirectory)) {
        New-Item -Path $statusDirectory -ItemType Directory -Force | Out-Null
    }

    $temporaryStatus = "$StatusFile.tmp"
    $status | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $temporaryStatus -Encoding UTF8
    Move-Item -LiteralPath $temporaryStatus -Destination $StatusFile -Force
}

function Invoke-EnforcementPass {
    $Script:PassCorrections = 0
    $Script:PassFindings = 0
    $Script:PassErrors = 0

    $passStarted = Get-Date
    $loadedProfiles = @()

    try {
        $loadedProfiles = @(Get-LoadedUserProfiles)
        Invoke-RegistryEnforcement -LoadedProfiles $loadedProfiles
        Invoke-ShortcutCleanup -LoadedProfiles $loadedProfiles
    }
    catch {
        $Script:PassErrors++
        Write-GuardLog -Level 'ERROR' -Message "Unhandled enforcement-pass error: $($_.Exception.Message)"
    }

    $passCompleted = Get-Date

    try {
        Write-StatusFile `
            -LoadedProfiles $loadedProfiles `
            -PassStarted $passStarted `
            -PassCompleted $passCompleted
    }
    catch {
        Write-GuardLog -Level 'ERROR' -Message "Failed to update status file. $($_.Exception.Message)"
    }

    if ($Script:PassErrors -eq 0) {
        Write-GuardLog -Level 'INFO' -Message "Pass completed. LoadedUsers=$(@($loadedProfiles).Count); Findings=$Script:PassFindings; Corrections=$Script:PassCorrections; Errors=0."
    }
    else {
        Write-GuardLog -Level 'WARNING' -Message "Pass completed with errors. LoadedUsers=$(@($loadedProfiles).Count); Findings=$Script:PassFindings; Corrections=$Script:PassCorrections; Errors=$Script:PassErrors."
    }
}

Initialize-GuardDirectories

Write-GuardLog `
    -Level 'INFO' `
    -Message "Desktop Policy Guard started. Version=1.0.0; AuditOnly=$([bool]$AuditOnly); RunOnce=$([bool]$RunOnce); Interval=$($Config.CheckIntervalSeconds)s."

do {
    Invoke-EnforcementPass

    if (-not $RunOnce) {
        Start-Sleep -Seconds ([int]$Config.CheckIntervalSeconds)
    }
}
while (-not $RunOnce)

Write-GuardLog -Level 'INFO' -Message 'Desktop Policy Guard completed.'
