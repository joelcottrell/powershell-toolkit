<#
.SYNOPSIS
    Installs the PowerShell profile selector directly from GitHub.
.DESCRIPTION
    Downloads only the bootstrap and lightweight local profile from a selected
    GitHub ref, validates syntax, backs up existing local files, and installs.
    Does not execute downloaded code during installation. No repository clone.
.NOTES
    File Name : Install-FromGitHub.ps1
    Author    : Joel Cottrell
    Version   : 1.0.0
    Changelog :
      1.0.0 - Initial direct GitHub installer.
.EXAMPLE
    .\Install-FromGitHub.ps1 -Ref main -WhatIf
.EXAMPLE
    .\Install-FromGitHub.ps1 -Ref main
#>
[CmdletBinding(SupportsShouldProcess=$true,ConfirmImpact='High')]
param(
    [ValidatePattern('^[a-zA-Z0-9._/-]+$')]
    [string]$Ref = 'main',
    [string]$BootstrapSha256,
    [string]$LocalSha256
)
$ErrorActionPreference = 'Stop'
$base = "https://raw.githubusercontent.com/joelcottrell/powershell-toolkit/$Ref/Shared/PowerShell-Profile"
$targetDirectory = Split-Path -Parent $PROFILE
$files = @(
    @{ Name='Import-RemoteProfile.ps1'; Destination=$PROFILE; Expected=$BootstrapSha256 }
    @{ Name='Local-Profile.ps1'; Destination=(Join-Path $targetDirectory 'Local-Profile.ps1'); Expected=$LocalSha256 }
)
$stagingDir = Join-Path ([IO.Path]::GetTempPath()) ('PSProfileInstall-' + [guid]::NewGuid().ToString('N'))
try {
    New-Item -ItemType Directory -Path $stagingDir -Force | Out-Null
    foreach ($item in $files) {
        $url = "$base/$($item.Name)"
        $stage = Join-Path $stagingDir $item.Name
        Invoke-WebRequest -Uri $url -OutFile $stage -ErrorAction Stop
        $tokens=$null; $parseErrors=$null
        $null=[System.Management.Automation.Language.Parser]::ParseFile($stage,[ref]$tokens,[ref]$parseErrors)
        if ($parseErrors.Count) { throw "Syntax validation failed: $($item.Name)" }
        $hash=(Get-FileHash -LiteralPath $stage -Algorithm SHA256).Hash
        Write-Host "$($item.Name) SHA256: $hash"
        if ($item.Expected -and $hash -ne $item.Expected) { throw "Hash mismatch for $($item.Name)" }
        $item.Stage = $stage
    }
    Write-Host "Review source at: https://github.com/joelcottrell/powershell-toolkit/tree/$Ref/Shared/PowerShell-Profile" -ForegroundColor Yellow
    if (-not $BootstrapSha256 -or -not $LocalSha256) {
        Write-Warning 'One or more expected SHA256 values were not supplied. Syntax checks alone do not prove authenticity.'
    }
    if ($PSCmdlet.ShouldProcess($PROFILE,'Back up and install downloaded PowerShell profiles')) {
        New-Item -ItemType Directory -Path $targetDirectory -Force | Out-Null
        $backups = @()
        foreach ($item in $files) {
            if (Test-Path -LiteralPath $item.Destination) {
                $backup = "$($item.Destination).backup.$(Get-Date -Format yyyyMMdd-HHmmss)-$([guid]::NewGuid().ToString('N').Substring(0,6))"
                Copy-Item -LiteralPath $item.Destination -Destination $backup -ErrorAction Stop
                $backups += $backup
                Write-Host "Backup: $backup"
            }
        }
        foreach ($item in $files) {
            Copy-Item -LiteralPath $item.Stage -Destination $item.Destination -Force -ErrorAction Stop
        }
        Write-Host 'Installed. Restart PowerShell and choose Y for the local profile.' -ForegroundColor Green
        Write-Host 'To install the full cached profile later, run Update-PowerShellProfile.'
    }
} finally {
    if (Test-Path -LiteralPath $stagingDir) {
        Remove-Item -LiteralPath $stagingDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}
