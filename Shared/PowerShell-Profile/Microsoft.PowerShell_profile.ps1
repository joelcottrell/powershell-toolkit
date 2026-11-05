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
        Set-PowerCLIConfiguration -Scope User -ParticipateInCEIP $false -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
        Set-PowerCLIConfiguration -Scope User -InvalidCertificateAction Ignore -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
    }

    try {
        Import-Module $Name -ErrorAction Stop
        Write-Host "[OK] Module '$Name' loaded successfully." -ForegroundColor Green
    } catch {
        Write-Warning "Failed to import $Name: $($_.Exception.Message)" -ForegroundColor DarkYellow
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
# Define modules to ensure are installed & loaded
#$RequiredModules = @("VMware.PowerCLI")  # Add any other modules you want, e.g. (, "Az", "posh-git")
$RequiredModules = @("VCF.PowerCLI")  # Add any other modules you want, e.g. (, "Az", "posh-git")
# Show welcome message with module list
Show-WelcomeMessage -ModulesToLoad $RequiredModules

# Import installed modules only. Module installation/update is a separate admin task.
foreach ($mod in $RequiredModules) {
    if (Get-Module -ListAvailable -Name $mod) {
        try { Import-Module -Name $mod -ErrorAction Stop; Write-Host "[OK] $mod loaded." -ForegroundColor Green }
        catch { Write-Warning "Failed to import $mod: $($_.Exception.Message)" }
    } else {
        Write-Warning "$mod is not installed. Install it explicitly when needed."
    }
}
