#Requires -Version 5.1
# Author: Joel Cottrell | Version: 1.0.13
$ErrorActionPreference='Stop'
$m=@(Import-Module (Join-Path (Split-Path $PSScriptRoot -Parent) 'Modules/ADMigration.ADUserMigration.psm1') -Force -PassThru)[0]
try { & $m {
    $before=[datetime]::UtcNow.AddDays(-10).ToFileTimeUtc().ToString()
    $after=[datetime]::UtcNow.AddMinutes(-1).ToFileTimeUtc().ToString()
    Assert-ADMigrationPasswordTimestamp @($before) ([long]$after)
    Write-Host 'PASS: Nonzero timestamp transformation accepts string/Int64 values'
    Assert-ADMigrationPasswordTimestamp 0 0
    Write-Host 'PASS: Existing must-change state preserved'
    foreach($pair in @(@(0,$after),@($before,0),@($before,'bad'),@($before,-1),@($after,$before),@($before,[datetime]::UtcNow.AddDays(1).ToFileTimeUtc().ToString()))) {
        $failed=$false;try{Assert-ADMigrationPasswordTimestamp $pair[0] $pair[1]}catch{$failed=$true}
        if(-not $failed){throw 'Invalid timestamp transition accepted'}
    }
    Write-Host 'PASS: Invalid, reversed, future and must-change-state transitions rejected'
    $plan=[pscustomobject]@{InvariantAttributes=[pscustomobject]@{pwdLastSet=@($before)}}
    $user=[pscustomobject]@{pwdLastSet=[long]$after}
    $failed=$false;try{Assert-ADMigrationInvariantAttributes $plan $user}catch{$failed=$true}
    if(-not $failed){throw 'Pre-move pwdLastSet drift was accepted'}
    Assert-ADMigrationInvariantAttributes $plan $user -AfterMove
    Write-Host 'PASS: Exact pre-move comparison retained; documented post-move transform allowed'
} } finally {Remove-Module $m -Force}
