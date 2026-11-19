#Requires -Version 5.1
# Author: Joel Cottrell | Version: 1.0.13
[CmdletBinding()]param([switch]$Portable)
$ErrorActionPreference='Stop'
foreach($test in @('Test-ADMigrationPackage','Test-ADMigrationCleanup','Test-ADMigrationCleanupDecisions','Test-ADMigrationExecution','Test-ADMigrationPasswordTimestamp','Test-ADMigrationPlanIntegrity','Test-ADMigrationSyntheticReplay','Test-ADMigrationGeneralAccounts')) {
 if($test -eq 'Test-ADMigrationPackage' -and $Portable){& (Join-Path $PSScriptRoot ($test+'.ps1')) -Portable}
 else {& (Join-Path $PSScriptRoot ($test+'.ps1'))}
}
Write-Host 'All offline suites passed. No live AD validation performed.'
