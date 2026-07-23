<#
.SYNOPSIS
    Loads a locally cached PowerShell profile and refreshes it only when asked.

.DESCRIPTION
    Bootstrap for your $PROFILE. Place the contents of this file in your profile
    (see README.md) to load a centrally managed profile across machines.

    The previous version of this script downloaded a profile from GitHub and
    dot-sourced it on every shell start. That gave every new PowerShell session
    the contents of a URL, tracking a moving branch, with no integrity check and
    no confirmation. Anyone who gained control of that path - a compromised
    account, or simply someone claiming a released username - would get code
    execution in every shell on every machine running the profile.

    This version closes that:

      - Shell start performs no network access at all. It dot-sources a local
        cached copy and nothing else.
      - Refreshing is explicit: you run Update-PowerShellProfile when you want
        new code, so remote changes never arrive silently.
      - Updates can be pinned to a tag or commit SHA rather than a branch, so a
        later force-push cannot change what you already reviewed.
      - The downloaded content is hashed and shown to you, and can be checked
        against an expected SHA256 before it is installed.
      - Installation is atomic, into your own profile directory, rather than
        staged through a predictable path in the shared temp directory.

    Trust model: you are trusting the code at the moment you run
    Update-PowerShellProfile, not on every shell start. Review what changed,
    then install it.

.PARAMETER Ref
    Branch, tag, or commit SHA to fetch from. Prefer a tag or SHA. Defaults to
    the value of $ProfileRef below.

.PARAMETER ExpectedSha256
    If supplied, the download is installed only when its SHA256 matches. Pin
    this once you have reviewed a known-good version.

.EXAMPLE
    Update-PowerShellProfile
    Fetches the profile, shows its SHA256, and asks before installing.

.EXAMPLE
    Update-PowerShellProfile -Ref 'v1.1' -ExpectedSha256 'ABC123...' -Force
    Non-interactive update pinned to a tag, installed only on hash match.

.NOTES
    File Name  : Import-RemoteProfile.ps1
    Author     : Joel Cottrell
    Version    : 2.0.0
    Requires   : PowerShell 5.1 or later

    Repository : https://github.com/bigjoestretch/powershell-toolkit
#>

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

# Prefer a tag or commit SHA over 'main'. A branch can change under you; a tag
# reviewed once stays what you reviewed.
$ProfileRef = 'main'

$ProfileSourceUrl = 'https://raw.githubusercontent.com/bigjoestretch/powershell-toolkit/{0}/Shared/PowerShell-Profile/Microsoft.PowerShell_profile.ps1'

# Once you have reviewed a version, paste its SHA256 here to refuse anything else.
$ProfileExpectedSha256 = ''

$ProfileCacheDir  = Join-Path (Split-Path -Parent $PROFILE) 'RemoteProfile'
$ProfileCachePath = Join-Path $ProfileCacheDir 'Microsoft.PowerShell_profile.ps1'

# ---------------------------------------------------------------------------
# Update command - run this deliberately, not automatically
# ---------------------------------------------------------------------------

function Update-PowerShellProfile {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param(
        [string]$Ref = $ProfileRef,
        [string]$ExpectedSha256 = $ProfileExpectedSha256,
        [switch]$Force
    )

    $url = $ProfileSourceUrl -f $Ref

    if ($Ref -eq 'main' -and -not $ExpectedSha256) {
        Write-Warning "Fetching from branch '$Ref' with no expected hash. Pin a tag or SHA256 for repeatable updates."
    }

    # Windows PowerShell 5.1 may still default to TLS 1.0/1.1, which GitHub rejects.
    try {
        [Net.ServicePointManager]::SecurityProtocol =
            [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    } catch {
        Write-Verbose "Could not raise TLS version: $_"
    }

    Write-Host "Fetching profile from $url" -ForegroundColor Cyan

    try {
        $response = Invoke-WebRequest -Uri $url -UseBasicParsing -ErrorAction Stop
    } catch {
        Write-Error "Download failed: $_"
        return
    }

    $content = $response.Content
    if ([string]::IsNullOrWhiteSpace($content)) {
        Write-Error "Downloaded profile was empty. Nothing installed."
        return
    }

    # Hash the exact bytes that would be installed.
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($content)
    $sha   = [System.Security.Cryptography.SHA256]::Create()
    try {
        $hash = ($sha.ComputeHash($bytes) | ForEach-Object { $_.ToString('x2') }) -join ''
    } finally {
        $sha.Dispose()
    }

    Write-Host "SHA256: $hash" -ForegroundColor Yellow

    if ($ExpectedSha256) {
        if ($hash -ne $ExpectedSha256.ToLowerInvariant()) {
            Write-Error "Hash mismatch. Expected $ExpectedSha256 but got $hash. Nothing installed."
            return
        }
        Write-Host "Hash matches the pinned value." -ForegroundColor Green
    }

    if (-not (Test-Path -LiteralPath $ProfileCacheDir)) {
        New-Item -Path $ProfileCacheDir -ItemType Directory -Force | Out-Null
    }

    # Show what is changing before it is trusted.
    if ((Test-Path -LiteralPath $ProfileCachePath) -and -not $Force) {
        $currentHash = Get-PowerShellProfileHash
        if ($currentHash -eq $hash) {
            Write-Host "Already up to date. Nothing to do." -ForegroundColor Green
            return
        }
        Write-Host "This will replace your cached profile (current SHA256: $currentHash)." -ForegroundColor Yellow
        Write-Host "Review the source at $url before continuing." -ForegroundColor Yellow
    }

    if (-not ($Force -or $PSCmdlet.ShouldProcess($ProfileCachePath, "Install updated PowerShell profile"))) {
        Write-Host "Cancelled. Nothing installed." -ForegroundColor DarkYellow
        return
    }

    # Write to a temporary file in the destination directory, then move into
    # place, so a failure part-way through cannot leave a truncated profile.
    $staging = Join-Path $ProfileCacheDir ([System.IO.Path]::GetRandomFileName())
    try {
        [System.IO.File]::WriteAllText($staging, $content, (New-Object System.Text.UTF8Encoding($false)))
        Move-Item -LiteralPath $staging -Destination $ProfileCachePath -Force
        Write-Host "[OK] Profile updated at $ProfileCachePath" -ForegroundColor Green
        Write-Host "Restart PowerShell, or run: . `$PROFILE" -ForegroundColor DarkGray
    } catch {
        Write-Error "Install failed: $_"
        if (Test-Path -LiteralPath $staging) { Remove-Item -LiteralPath $staging -Force -ErrorAction SilentlyContinue }
    }
}

function Get-PowerShellProfileHash {
    [CmdletBinding()]
    param([string]$Path = $ProfileCachePath)

    if (-not (Test-Path -LiteralPath $Path)) { return $null }
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

# ---------------------------------------------------------------------------
# Shell start - local only, no network
# ---------------------------------------------------------------------------

if (-not $env:PS_SKIP_PROFILE) {
    if (Test-Path -LiteralPath $ProfileCachePath) {
        try {
            . $ProfileCachePath
        } catch {
            Write-Warning "[WARN] Cached profile failed to load: $_"
            Write-Warning "Loaded a bare session. Fix or re-run Update-PowerShellProfile."
        }
    } else {
        Write-Host "No cached profile found. Run Update-PowerShellProfile to install one." -ForegroundColor DarkYellow
    }
}
