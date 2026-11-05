# Ensure a module is installed, updated if needed, and imported
function global:Ensure-Module {
    param (
        [Parameter(Mandatory = $true)][string]$Name,
        [string]$Repository = "PSGallery",
        [switch]$ForceInstall
    )

    $installed = Get-Module -ListAvailable -Name $Name | Sort-Object Version -Descending | Select-Object -First 1
    # Module update checks are intentionally excluded from interactive startup.
    $online = $null

    if (-not $installed) {
        try {
            Write-Host "[PKG] Installing module: $Name" -ForegroundColor Yellow
            Install-Module -Name $Name -Repository $Repository -Scope CurrentUser -Force:$ForceInstall -AllowClobber -ErrorAction Stop -Confirm:$False
        } catch {
            Write-Host "[FAIL] Failed to install module: $Name" -ForegroundColor Red
            Write-Host $_.Exception.Message
        }
    } elseif ($false -and $online.Version -gt $installed.Version) {
        try {
            Write-Host "[UPDATE] Updating $Name from $($installed.Version) -> $($online.Version)" -ForegroundColor Yellow
            Update-Module -Name $Name -Force:$ForceInstall -ErrorAction Stop -Confirm:$False
        } catch {
            Write-Host "[FAIL] Failed to update module: $Name" -ForegroundColor Red
            Write-Host $_.Exception.Message
        }
    }

<#	if ($Name -eq "VMware.PowerCLI") {
        # Leave persistent PowerCLI settings to explicit administration.
        # Do not disable TLS certificate verification during profile initialization.
    }
#>

	if ($Name -eq "VCF.PowerCLI") {
        # PowerCLI configuration is intentionally not changed at startup.
    }

    try {
        Import-Module $Name -ErrorAction Stop
        Write-Host "[OK] Module '$Name' loaded successfully." -ForegroundColor Green
    } catch {
        Write-Warning "Failed to import ${Name}: $($_.Exception.Message)"
    }
}

# Store session start time when profile is loaded
if (-not $global:SessionStartTime) {
    $global:SessionStartTime = Get-Date
}

function global:Get-BatteryStatus {
    $battery = Get-CimInstance Win32_Battery
    if ($battery) {
        return "$($battery.EstimatedChargeRemaining)% BAT"
    }
    return ""
}

function global:Get-CPULoad {
    $cpu = Get-Counter '\Processor(_Total)\% Processor Time'
    $usage = [math]::Round($cpu.CounterSamples[0].CookedValue, 1)
    return "$usage% CPU"
}

function global:Get-TimeIcon {
    $hour = (Get-Date).Hour
    switch ($hour) {
        { $_ -lt 6 } { return "(night)" }
        { $_ -lt 12 } { return "(morning)" }
        { $_ -lt 18 } { return "(afternoon)" }
        default { return "(evening)" }
    }
}

function global:Get-RandomQuote {
    $quotes = @(
		"Dream big. Start now."
		"You've got this."
		"Be relentless."
		"Make it happen."
		"Create your future."
		"Progress, not perfection."
		"Stay hungry."
		"Rise and grind."
		"Own your power."
		"Push. Persist. Prevail."
    )
    return $quotes | Get-Random
}

function global:Get-SessionUptime () {
    $elapsed = (Get-Date) - $global:SessionStartTime
    return "{0}m" -f [math]::Floor($elapsed.TotalMinutes)
}

function global:Get-TimezoneAbbr {
    # Map known timezone names to abbreviations (expand as needed)
    $tzMap = @{
        "Pacific Standard Time" = "PST"
        "Pacific Daylight Time" = "PDT"
        "Mountain Standard Time" = "MST"
        "Mountain Daylight Time" = "MDT"
        "Central Standard Time" = "CST"
        "Central Daylight Time" = "CDT"
        "Eastern Standard Time" = "EST"
        "Eastern Daylight Time" = "EDT"
    }

    $tz = [System.TimeZoneInfo]::Local
    $isDST = $tz.IsDaylightSavingTime([DateTime]::Now)
    $fullName = if ($isDST) { $tz.DaylightName } else { $tz.StandardName }

    if ($tzMap.ContainsKey($fullName)) { return $tzMap[$fullName] }
    return $fullName
}

function global:Show-WelcomeMessage {
    param (
        [string[]]$ModulesToLoad = @()
    )

    $hour = (Get-Date).Hour
    $username = $env:USERNAME
    $quote = Get-RandomQuote
    $greeting = ""
    $color = "White"
	$name = "Joel" # Change this to your name
    switch ($hour) {
        { $_ -lt 12 } {
            $greeting = "Good morning $name"
            $color = "Yellow"
            break
        }
        { $_ -lt 18 } {
            $greeting = "Good afternoon $name"
            $color = "Green"
            break
        }
        default {
            $greeting = "Good evening $name"
            $color = "Cyan"
        }
    }

    Write-Host ""
    Write-Host "==========================================" -ForegroundColor DarkGray
    Write-Host $greeting -ForegroundColor $color
    Write-Host "Welcome to PowerShell! " -ForegroundColor Magenta -NoNewline
    Write-Host "$quote" -ForegroundColor Cyan
	Write-Host "==========================================" -ForegroundColor DarkGray

    if ($ModulesToLoad.Count -gt 0) {
        Write-Host "`n[PKG] Loading modules..." -ForegroundColor DarkCyan
        foreach ($module in $ModulesToLoad) {
            Write-Host "-> $module" -ForegroundColor DarkGray
        }
    }
}

function global:prompt {
    $now = Get-Date
    $time = $now.ToString("hh:mm:ss tt")
    $date = $now.ToString("MM/dd/yyyy")
    $tz = Get-TimezoneAbbr
    $uptime = Get-SessionUptime
    $battery = $null
    # CPU polling on every prompt is expensive; omit unless explicitly requested.
    $cpu = $null
    $icon = Get-TimeIcon
    $user = $env:USERNAME
    $cwd = (Get-Location).Path
    $base = Split-Path $cwd -Parent
    $folder = Split-Path $cwd -Leaf

    # Greeting and system info
    Write-Host "`n$icon $date | [$time] | PowerShell Console Uptime: $uptime" -ForegroundColor Green

    # Prompt line with highlighted current folder
    $shortTime = $now.ToString("hh:mm:ss tt")
	Write-Host "`n[$shortTime] " -NoNewline -ForegroundColor Red
	Write-Host "> $base\" -NoNewline -ForegroundColor DarkGray
    Write-Host "$folder>" -NoNewline -ForegroundColor Cyan

    return " "
}

# Infrastructure module manager is embedded for standalone cached profile loading.
<#
.SYNOPSIS
  Select and maintain infrastructure PowerShell modules.
.NOTES
  File Name: Infrastructure-ModuleManager.ps1
  Author: Joel Cottrell
  Created: 2026-11-05
  Version: 1.0.0
  Changelog:
    1.0.0 - Per-module 24-hour updates, installation and imports.
#>
$global:InfrastructureModules = @{ VMware=@('VCF.PowerCLI'); Nutanix=@('Nutanix.Prism','Nutanix.Vmm') }
$global:InfrastructureStatePath = Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'PowerShellProfile\module-state.json'
function global:Invoke-InfrastructureModules {
    [CmdletBinding()]
    param([Parameter(Mandatory)][ValidateSet('VMware','Nutanix')][string]$Platform)
    $state=@{}
    if (Test-Path -LiteralPath $global:InfrastructureStatePath) {
        try { $state=Get-Content -LiteralPath $global:InfrastructureStatePath -Raw | ConvertFrom-Json -AsHashtable }
        catch { Write-Warning "State unreadable: $($_.Exception.Message)" }
    }
    if (-not $state) { $state=@{} }
    foreach ($name in $global:InfrastructureModules[$Platform]) {
        $installed=Get-Module -ListAvailable -Name $name | Sort-Object Version -Descending | Select-Object -First 1
        $loaded=Get-Module -Name $name | Sort-Object Version -Descending | Select-Object -First 1
        $last=[datetime]::MinValue
        if ($state.ContainsKey($name)) {
            $parsed=[datetime]::MinValue
            if ([datetime]::TryParse([string]$state[$name],[ref]$parsed)) { $last=$parsed.ToUniversalTime() }
        }
        $due=(-not $installed) -or (([datetime]::UtcNow-$last).TotalHours -ge 24)
        $changed=$false
        if ($due) {
            try {
                $available=Find-Module -Name $name -Repository PSGallery -ErrorAction Stop
                $latest=[version]$available.Version
                if (-not $installed) {
                    $answer=Read-Host "$name is missing (latest $latest). Install? [y/N]"
                    if ($answer -match '^(?i:y|yes)$') {
                        Install-Module -Name $name -Repository PSGallery -Scope CurrentUser -RequiredVersion $latest -Force -AllowClobber -ErrorAction Stop
                        $changed=$true
                    } else { Write-Warning "Installation declined for $name." }
                } elseif ($latest -gt $installed.Version) {
                    Write-Host "$name update $($installed.Version) -> $latest. Installing..." -ForegroundColor Cyan
                    Install-Module -Name $name -Repository PSGallery -Scope CurrentUser -RequiredVersion $latest -Force -AllowClobber -ErrorAction Stop
                    $changed=$true
                } else { Write-Host "$name is current ($($installed.Version))." }
                $state[$name]=[datetime]::UtcNow.ToString('o')
                New-Item -ItemType Directory -Path (Split-Path -Parent $global:InfrastructureStatePath) -Force | Out-Null
                $state | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $global:InfrastructureStatePath -Encoding utf8
            } catch {
                Write-Warning "Update failed for $($name): $($_.Exception.Message)"
                Write-Warning 'Publisher validation is not bypassed automatically.'
            }
        }
        $installed=Get-Module -ListAvailable -Name $name | Sort-Object Version -Descending | Select-Object -First 1
        if (-not $installed) { continue }
        if ($loaded -and $changed) {
            Write-Warning "$name updated on disk. Restart PowerShell to use the new version."
            continue
        }
        if ($loaded) { Write-Host "$name $($loaded.Version) already loaded."; continue }
        try {
            Import-Module -Name $name -RequiredVersion $installed.Version -ErrorAction Stop
            Write-Host "$name $($installed.Version) loaded." -ForegroundColor Green
        } catch {
            Write-Warning "Import failed for $($name): $($_.Exception.Message)"
            Write-Warning 'A fresh PowerShell session may be needed for conflicting assemblies.'
        }
    }
}
function global:Load-VCF { Invoke-InfrastructureModules -Platform VMware }
function global:Load-Nutanix { Invoke-InfrastructureModules -Platform Nutanix }

function global:Select-InfrastructureModules {
    if (-not [Environment]::UserInteractive -or [Console]::IsInputRedirected -or $Host.Name -ne 'ConsoleHost') { return }
    Write-Host ''
    Write-Host 'Select infrastructure modules:' -ForegroundColor Cyan
    Write-Host '  1 - VMware VCF.PowerCLI'
    Write-Host '  2 - Nutanix modern v4 SDK (Prism + VMM)'
    Write-Host '  3 - Both'
    Write-Host '  4 - None (default)'
    $choice = Read-Host 'Select [1/2/3/4]'
    switch ($choice) {
        '1' { Load-VCF }
        '2' { Load-Nutanix }
        '3' { Load-VCF; Load-Nutanix }
        default { Write-Host 'No infrastructure modules selected.' -ForegroundColor DarkGray }
    }
}
Show-WelcomeMessage
Select-InfrastructureModules
