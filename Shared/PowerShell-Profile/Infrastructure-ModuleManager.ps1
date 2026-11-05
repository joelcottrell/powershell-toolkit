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
