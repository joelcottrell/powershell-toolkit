# Author: Joel Cottrell | Version 1.0.13
# Offline mocks only. No AD connection or deletion.
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$modulePath=(Resolve-Path -LiteralPath (Join-Path $root 'Modules/ADMigration.ADUserMigration.psm1')).ProviderPath
$importedModules=@(Import-Module $modulePath -Force -PassThru)
if ($importedModules.Count -ne 1) { throw 'Expected exactly one module from this import.' }
$m=$importedModules[0]
if ($m.Path -ne $modulePath) { throw 'Imported module path differs from this package.' }
& $m {
    $script:n105=0
    function Check($ok,$msg) { if(-not $ok){throw "FAIL: $msg"};$script:n105++;Write-Host "PASS: $msg" }
    function Reject($f,$msg) {$r=$false;try{&$f}catch{$r=$true};Check $r $msg}
    function Assert-ADMigrationSecurityPreflight {}
    function Get-ADMigrationCleanupOperator { [pscustomobject]@{Name='TEST\operator';SID='operator'} }
    function Protect-ADMigrationDirectory {}
    function Export-ADMigrationSnapshot {param($Objects,$Path)}
    function Get-ADDomain { [pscustomobject]@{RIDMaster='mock.test';DNSRoot='branch.example.test';DomainSID=[pscustomobject]@{Value='domain'}} }
    function Get-ADDomainController { [pscustomobject]@{IsReadOnly=$false;Domain='branch.example.test'} }
    $script:user105=[pscustomobject]@{ObjectGUID=[guid]'11111111-2222-3333-4444-555555555555';SamAccountName='TEST100';DistinguishedName='CN=FixtureUser,DC=branch,DC=example,DC=test';SID=[pscustomobject]@{Value='user';AccountDomainSid=[pscustomobject]@{Value='domain'}};adminCount=0;ProtectedFromAccidentalDeletion=$false}
    function Get-ADUser { $script:user105 }
    function New-Children {
        @([pscustomobject]@{ObjectGUID=[guid]'11111111-1111-1111-1111-111111111111';DistinguishedName='CN=devices,CN=FixtureUser,DC=branch,DC=example,DC=test';ObjectClass='msExchActiveSyncDevices';uSNChanged=10;ProtectedFromAccidentalDeletion=$false},
        [pscustomobject]@{ObjectGUID=[guid]'22222222-2222-2222-2222-222222222222';DistinguishedName='CN=iPhone'+[char]0x00A7+'Test,CN=devices,CN=FixtureUser,DC=branch,DC=example,DC=test';ObjectClass='msExchActiveSyncDevice';uSNChanged=20;ProtectedFromAccidentalDeletion=$false})
    }
    function Get-ADMigrationCleanupInventory { @($script:children105) }
    function Get-ADObject { @() }
    function Read-Host { $script:phrase105 }
    function Remove-ADObject {
        param($Identity,$Server,$Confirm,$ErrorAction)
        $script:deletions105+=@([string]$Identity)
        if ($script:fail105 -and $script:deletions105.Count -eq 2) {throw 'Injected deletion failure'}
        $script:children105=@($script:children105 | Where-Object { $_.ObjectGUID -ne $Identity })
    }
    $temp=Join-Path ([IO.Path]::GetTempPath()) ('ADMigration-CleanupTests-'+[guid]::NewGuid())
    $d=[pscustomobject]@{Config=[pscustomobject]@{ForestRoot='example.test'};Direction=[pscustomobject]@{SourceDomain='branch.example.test'};Row=[pscustomobject]@{SamAccountName='TEST100';ChangeReference='TEST-1'};CsvHash='csv';MapHash='map';ConfigHash='config'}
    $args105=@{InputData=$d;ExpectedUserGUID=$script:user105.ObjectGUID;OutputRoot=$temp;Confirm=$false}
    $script:children105=New-Children;$script:deletions105=@();$script:fail105=$false;$script:phrase105='CLEANUP TEST100'
    try {
        $preview=Invoke-ADMigrationActiveSyncCleanup @args105
        Check ($preview.Status -eq 'PreviewOnly' -and $script:deletions105.Count -eq 0) 'Default preview never deletes'
        $plan=Join-Path $preview.Directory 'PreviewPlan.json'
        $r=Invoke-ADMigrationActiveSyncCleanup @args105 -Execute -PlanPath $plan -WhatIf
        Check ($r.Status -eq 'WhatIf' -and $script:deletions105.Count -eq 0) 'Execute WhatIf never deletes'
        $script:children105[1].uSNChanged=21
        Reject {Invoke-ADMigrationActiveSyncCleanup @args105 -Execute -PlanPath $plan} 'Stale preview blocks execution'
        Check ($script:deletions105.Count -eq 0) 'Stale preview causes zero deletions'
        $script:children105=New-Children;$script:phrase105='CANCEL'
        $r=Invoke-ADMigrationActiveSyncCleanup @args105 -Execute -PlanPath $plan
        Check ($r.Status -eq 'Cancelled' -and $script:deletions105.Count -eq 0) 'Wrong typed confirmation cancels execution'
        $script:phrase105='CLEANUP TEST100'
        $r=Invoke-ADMigrationActiveSyncCleanup @args105 -Execute -PlanPath $plan
        Check ($r.Status -eq 'CleanupVerifiedOnSourceRID') 'Successful mocked cleanup verifies no remaining children'
        Check ($script:deletions105[0] -eq '22222222-2222-2222-2222-222222222222') 'Device deleted before container'
        Check ($script:deletions105 -notcontains [string]$script:user105.ObjectGUID) 'User GUID never deleted'
        $script:children105=New-Children;$script:deletions105=@();$script:fail105=$true
        Reject {Invoke-ADMigrationActiveSyncCleanup @args105 -Execute -PlanPath $plan} 'Mid-cleanup failure stops execution'
        $states=@(Get-ChildItem $temp -Recurse -Filter CleanupState.json | ForEach-Object {Get-Content $_.FullName -Raw -Encoding UTF8 | ConvertFrom-Json})
        $failed=@($states | Where-Object Status -eq FailedOrPartial)
        Check ($failed.Count -eq 1 -and $failed[0].CompletedGUIDs.Count -eq 1 -and $failed[0].PendingGUID -eq '11111111-1111-1111-1111-111111111111') 'Partial state records completed and uncertain pending deletion'
        $script:children105=New-Children;$script:children105[1].ObjectClass='container'
        Reject {Invoke-ADMigrationActiveSyncCleanup @args105} 'Unknown child blocks entire cleanup'
        $script:children105=New-Children;$script:children105[1].ProtectedFromAccidentalDeletion=$true
        Reject {Invoke-ADMigrationActiveSyncCleanup @args105} 'Protected child blocks entire cleanup'
        Write-Host "All $script:n105 cleanup workflow assertions passed with mocks. No live AD validation."
    } finally {if(Test-Path $temp){Remove-Item $temp -Recurse -Force}}
}
