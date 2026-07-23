# ==============================
# Bootstrap: Pull & Load PowerShell profile from GitHub
# ==============================

if (-not $env:PS_FAST_MODE) {

    $remoteProfile = 'https://raw.githubusercontent.com/bigjoestretch/powershell-toolkit/main/Shared/PowerShell-Profile/Microsoft.PowerShell_profile.ps1'
    $tempProfile   = Join-Path $env:TEMP 'remote_profile.ps1'

    try {
        Invoke-RestMethod -Uri $remoteProfile -OutFile $tempProfile -ErrorAction Stop
        . $tempProfile
        Write-Host "[OK] Remote PowerShell profile loaded from bigjoestretch's GitHub" -ForegroundColor Green
    }
    catch {
        Write-Warning "[WARN] Failed to load remote PowerShell profile: $_"
    }
}
