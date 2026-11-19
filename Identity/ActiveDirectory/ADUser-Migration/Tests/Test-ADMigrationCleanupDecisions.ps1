# Author: Joel Cottrell | Version 1.0.13
$ErrorActionPreference='Stop'
$packageRoot=Split-Path $PSScriptRoot -Parent
$modulePath=(Resolve-Path -LiteralPath (Join-Path $packageRoot 'Modules/ADMigration.ADUserMigration.psm1')).ProviderPath
$importedModules=@(Import-Module $modulePath -Force -PassThru)
if ($importedModules.Count -ne 1) { throw 'Expected exactly one module from this import.' }
$m=$importedModules[0]
if ($m.Path -ne $modulePath) { throw 'Imported module path differs from this package.' }
& $m { param($root)
 function Check($ok,$msg) {if(-not $ok){throw $msg};Write-Host "PASS: $msg"}
 function Reject($f,$msg) {$r=$false;try{&$f}catch{$r=$true};Check $r $msg}
 $obj=[pscustomobject]@{ObjectGUID=[guid]::NewGuid();DistinguishedName='CN=device,CN=user,DC=example';ObjectClass='msExchActiveSyncDevice';uSNChanged=100;ProtectedFromAccidentalDeletion=$false}
 $a=@(ConvertTo-ADMigrationCleanupItems @($obj));Check ($a.Count -eq 1) 'Exact device class accepted'
 $obj.ObjectClass='container';Reject {ConvertTo-ADMigrationCleanupItems @($obj)} 'Generic container blocked'
 $obj.ObjectClass='msExchActiveSyncDevices';$obj.ProtectedFromAccidentalDeletion=$true;Reject {ConvertTo-ADMigrationCleanupItems @($obj)} 'Protected child blocked'
 $obj.ProtectedFromAccidentalDeletion=$null;Reject {ConvertTo-ADMigrationCleanupItems @($obj)} 'Unknown protection state blocked'
 $obj.ProtectedFromAccidentalDeletion=$false;$obj.uSNChanged='';Reject {ConvertTo-ADMigrationCleanupItems @($obj)} 'Missing USN blocked'
 $obj.uSNChanged=101;$obj.ObjectClass='msExchActiveSyncDevice';$b=@(ConvertTo-ADMigrationCleanupItems @($obj));Reject {Assert-ADMigrationCleanupItemsEqual $a $b} 'Changed USN blocks stale plan'
 Reject {Assert-ADMigrationCleanupItemsEqual $a @()} 'Missing child blocks stale plan'
 $unicode=[pscustomobject]@{GUID=[guid]::NewGuid().ToString();DN='CN=iPhone'+[char]0x00A7+'Test,CN=user,DC=example';Class='msExchActiveSyncDevice';USN='123'}
 $unicodePath=Join-Path ([IO.Path]::GetTempPath()) ('ADMigration-Unicode-'+[guid]::NewGuid()+'.json')
 try {
  Write-ADMigrationJson @($unicode) $unicodePath
  $roundTrip=@(Get-Content -LiteralPath $unicodePath -Raw -Encoding UTF8 | ConvertFrom-Json)
  Assert-ADMigrationCleanupItemsEqual @($unicode) $roundTrip
  Check ($roundTrip[0].DN -ceq $unicode.DN) 'UTF8 plan preserves section sign in ActiveSync DN'
  $corrupt=[pscustomobject]@{GUID=$unicode.GUID;DN='CN=iPhone'+[char]0x00C2+[char]0x00A7+'Test,CN=user,DC=example';Class=$unicode.Class;USN=$unicode.USN}
  Reject {Assert-ADMigrationCleanupItemsEqual @($unicode) @($corrupt)} 'Mojibake DN remains blocked, not normalized away'
 } finally {Remove-Item -LiteralPath $unicodePath -Force -ErrorAction SilentlyContinue}
 Assert-ADMigrationCleanupItemsEqual $a $a;Check $true 'Unchanged inventory accepted'
 $d=[pscustomobject]@{Row=[pscustomobject]@{MigrationDirection='CHILD_TO_ROOT';ChangeReference='TEST-1'};Maps=@([pscustomobject]@{MigrationDirection='CHILD_TO_ROOT';SourceGroupSID='S-1-5-21-111-222-333-1001';TargetGroupSID='';Action='Omit';ApprovedBy='Test';ApprovalReference='Fixture';SourceUserGUID='11111111-2222-3333-4444-555555555555';ChangeReference='TEST-1'})}
 $g=[pscustomobject]@{SID='S-1-5-21-111-222-333-1001';Name='FixtureGroup';IsPrimary=$false;Scope='Global';Domain='branch.example.test';Category='Security'}
 $c=[pscustomobject]@{State=[pscustomobject]@{SourceGUID='11111111-2222-3333-4444-555555555555'}}
 $target=[pscustomobject]@{DNSRoot='example.test';DistinguishedName='DC=example,DC=test';RIDMaster='mock'}
 $r=@(Get-ADMigrationMappingAnalysis @($g) $d $target $c);Check ($r[0].Status -eq 'ConfiguredOmit') 'Fictional account exact GUID and ticket approval resolves omission'
 function Get-ADGroup { @() };function Add-UserMigrationFinding {}
 $c.State.SourceGUID=[guid]::NewGuid().ToString();$r=@(Get-ADMigrationMappingAnalysis @($g) $d $target $c);Check ($r[0].Status -eq 'Unmapped') 'Omission does not apply to another user'
 $c.State.SourceGUID='11111111-2222-3333-4444-555555555555';$d.Row.ChangeReference='CHANGE-999';$r=@(Get-ADMigrationMappingAnalysis @($g) $d $target $c);Check ($r[0].Status -eq 'Unmapped') 'Omission does not apply to a different ticket'
} $packageRoot
