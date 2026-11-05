<#
.SYNOPSIS
    Interactive, cached PowerShell profile selector.
.DESCRIPTION
    Loads the lightweight local profile by default, or a previously reviewed
    GitHub-managed profile from the local cache. Never downloads on startup.
.NOTES
    File Name : Import-RemoteProfile.ps1
    Author    : Joel Cottrell
    Version   : 2.1.0
    Changelog :
      2.1.0 - Add local/full startup selection and on-demand full loading.
      2.0.0 - Add explicit, verified cached profile updates.
.EXAMPLE
    Load-FullProfile
#>
$script:ProfileRef = 'main'
$script:ProfileSourceUrl = 'https://raw.githubusercontent.com/joelcottrell/powershell-toolkit/{0}/Shared/PowerShell-Profile/Microsoft.PowerShell_profile.ps1'
$script:ProfileExpectedSha256 = ''
$script:ProfileDirectory = Split-Path -Parent $PROFILE
$script:ProfileCacheDir = Join-Path $script:ProfileDirectory 'RemoteProfile'
$script:ProfileCachePath = Join-Path $script:ProfileCacheDir 'Microsoft.PowerShell_profile.ps1'
$script:LocalProfilePath = Join-Path $script:ProfileDirectory 'Local-Profile.ps1'
$global:ProfileHealth = [ordered]@{ Mode='Local'; RemoteDownload=$false; SyntaxValid=$false; LoadedRemote=$false; UsedFallback=$false; Error=$null }

function Test-ProfileSyntax {
    param([Parameter(Mandatory)][string]$Path)
    $tokens = $null; $parseErrors = $null
    $null = [System.Management.Automation.Language.Parser]::ParseFile($Path,[ref]$tokens,[ref]$parseErrors)
    return ($parseErrors.Count -eq 0)
}
function Get-PowerShellProfileHash {
    [CmdletBinding()]
    param([string]$Path = $script:ProfileCachePath)
    if (Test-Path -LiteralPath $Path) { (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant() }
}
function Update-PowerShellProfile {
    [CmdletBinding(SupportsShouldProcess=$true,ConfirmImpact='High')]
    param([string]$Ref=$script:ProfileRef,[string]$ExpectedSha256=$script:ProfileExpectedSha256,[switch]$Force)
    $url = $script:ProfileSourceUrl -f $Ref
    if ($Ref -eq 'main' -and -not $ExpectedSha256) {
        Write-Warning 'Using a moving branch without an expected hash. Prefer a reviewed commit SHA and expected hash.'
    }
    $directory = $script:ProfileCacheDir
    New-Item -ItemType Directory -Path $directory -Force -ErrorAction Stop | Out-Null
    $staging = Join-Path $directory ([IO.Path]::GetRandomFileName() + '.ps1')
    try {
        Invoke-WebRequest -Uri $url -OutFile $staging -ErrorAction Stop
        if (-not (Test-ProfileSyntax -Path $staging)) { throw 'Downloaded profile has PowerShell syntax errors.' }
        $hash = (Get-FileHash -LiteralPath $staging -Algorithm SHA256).Hash.ToLowerInvariant()
        Write-Host "Downloaded SHA256: $hash"
        if ($ExpectedSha256 -and $hash -ne $ExpectedSha256.ToLowerInvariant()) { throw 'Expected SHA256 does not match downloaded content.' }
        if (-not $Force -and (Get-PowerShellProfileHash) -eq $hash) { Write-Host 'Profile already current.'; return }
        Write-Host "Review source before installing: $url" -ForegroundColor Yellow
        if ($Force -or $PSCmdlet.ShouldProcess($script:ProfileCachePath,'Replace cached PowerShell profile')) {
            Move-Item -LiteralPath $staging -Destination $script:ProfileCachePath -Force -ErrorAction Stop
            Write-Host 'Cached profile updated. Run Load-FullProfile when ready.' -ForegroundColor Green
        }
    } catch { Write-Warning "Profile update failed: $($_.Exception.Message)" }
    finally { if (Test-Path -LiteralPath $staging) { Remove-Item -LiteralPath $staging -Force -ErrorAction SilentlyContinue } }
}
function Load-LocalProfile {
    $global:ProfileHealth.Mode = 'Local'
    if (Test-Path -LiteralPath $script:LocalProfilePath) {
        . $script:LocalProfilePath
    }
}
function Load-FullProfile {
    [CmdletBinding()]
    param()
    if ($global:ProfileHealth.LoadedRemote) { Write-Host 'Full profile already loaded.'; return }
    try {
        if (-not (Test-Path -LiteralPath $script:ProfileCachePath)) { throw 'No cached full profile. Run Update-PowerShellProfile to install a reviewed copy.' }
        if (-not (Test-ProfileSyntax -Path $script:ProfileCachePath)) { throw 'Cached profile failed syntax validation.' }
        $global:ProfileHealth.SyntaxValid = $true
        . $script:ProfileCachePath
        $global:ProfileHealth.LoadedRemote = $true
        $global:ProfileHealth.Mode = 'Full (cached GitHub)'
        Write-Host 'Full cached PowerShell profile loaded.' -ForegroundColor Green
    } catch {
        $global:ProfileHealth.Error = $_.Exception.Message
        $global:ProfileHealth.UsedFallback = $true
        Write-Warning "Full profile unavailable: $($_.Exception.Message)"
        Load-LocalProfile
    }
}
function Show-ProfileHealth {
    [CmdletBinding()]
    param()
    [pscustomobject]$global:ProfileHealth | Format-List
}
function Start-PowerShellProfile {
    if ($env:PS_SKIP_PROFILE -eq '1' -or $env:PS_PROFILE_MODE -eq 'local') { Load-LocalProfile; return }
    if ($env:PS_PROFILE_MODE -eq 'full') { Load-FullProfile; return }
    # Avoid blocking automation, redirected stdin, or nested sessions.
    if (-not [Environment]::UserInteractive -or [Console]::IsInputRedirected -or $Host.Name -ne 'ConsoleHost') {
        Load-LocalProfile; return
    }
    try {
        $choice = Read-Host 'Load local PowerShell profile? [Y/n]'
        if ($choice -match '^(?i:n|no)$') { Load-FullProfile } else { Load-LocalProfile }
    } catch { Load-LocalProfile }
}
Start-PowerShellProfile
