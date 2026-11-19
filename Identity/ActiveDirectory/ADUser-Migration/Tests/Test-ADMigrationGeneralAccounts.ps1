#Requires -Version 5.1
# Author: Joel Cottrell | Version: 1.0.13
[CmdletBinding()]param()
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$m=@(Import-Module (Join-Path $root 'Modules/ADMigration.ADUserMigration.psm1') -Force -PassThru)[0]
$temp=Join-Path ([IO.Path]::GetTempPath()) ('ADMigration-General-'+[guid]::NewGuid())
[void][IO.Directory]::CreateDirectory($temp)
try { & $m {param($temp)
 function Check($ok,$message){if(-not $ok){throw $message};Write-Host "PASS: $message"}
 function script:Invoke-ADMigrationAudit {param($InputData,$OutputRoot)
  $dir=Join-Path $OutputRoot ([guid]::NewGuid().ToString());[void][IO.Directory]::CreateDirectory($dir)
  $summary=[ordered]@{DistinguishedName=@('CN=Fictional,DC=source,DC=test');SID=@('S-1-5-21-111-222-333-9999');SIDHistory=@();uSNChanged=@('100');UserPrincipalName=@('fictional@example.test')}
  foreach($name in @('employeeID','mail','proxyAddresses','pwdLastSet','userAccountControl','homeDirectory','homeDrive','profilePath','department','company','manager','telephoneNumber','mobile')+(1..15|ForEach-Object {'extensionAttribute'+$_})){$summary[$name]=@()}
  $pre=[pscustomobject]@{State=[pscustomobject]@{SourceGUID=$script:fixtureGuid};TargetRIDMaster='t.example.test';SourceRIDMaster='s.example.test';Groups=$script:groups;GroupMappings=$script:mappings;Operator=[pscustomobject]@{Name='FixtureAdmin'};Findings=@();ChildObjects=@()}
  Write-ADMigrationJson $pre (Join-Path $dir 'PreMigration.json');Write-ADMigrationJson $summary (Join-Path $dir 'UserSummary.json')
  Write-ADMigrationJson ([pscustomobject]@{Items=@([pscustomobject]@{Attributes=[pscustomobject]@{DisplayName='Fictional'}})}) (Join-Path $dir 'UserRawAttributes.json')
  Write-ADMigrationJson @() (Join-Path $dir 'EvidenceHashes.json')
  [pscustomobject]@{Status='ReviewRequired';Directory=$dir}
 }
 function script:Get-ADDomain {param($Identity,$Server) [pscustomobject]@{DomainSID=[pscustomobject]@{Value='S-1-5-21-444-555-666'}}}
 function script:Move-ADObject {throw 'Preview reached mutation'}
 function script:Add-ADGroupMember {throw 'Preview reached mutation'}
 function script:Set-ADGroup {throw 'Preview reached mutation'}
 $script:groups=@([pscustomobject]@{Name='Domain Users';SID='S-1-5-21-111-222-333-513';ObjectGUID=[guid]::NewGuid().ToString();Domain='source.test';DistinguishedName='CN=Domain Users,DC=source,DC=test';Scope='Global';Category='Security';IsPrimary=$true})
 $script:mappings=@([pscustomobject]@{SourceSID=$script:groups[0].SID;Status='PrimaryGroupReview';TargetSID='';TargetDN='';Approval=''})
 foreach($direction in @('ROOT_TO_CHILD','CHILD_TO_ROOT')){
  $script:fixtureGuid=[guid]::NewGuid().ToString()
  $data=[pscustomobject]@{Row=[pscustomobject]@{SamAccountName='NEW123';ChangeReference='TEST-100';MigrationDirection=$direction;TargetOU='OU=Users,DC=target,DC=test'};Direction=[pscustomobject]@{SourceDomain='source.test';TargetDomain='target.test'};CsvHash='a';ConfigHash='b';MapHash='c'}
  $result=New-UserMigrationExecutionPreview $data ([guid]::Empty) $temp
  $p=Read-ADMigrationExecutionJson $result.PlanPath
  Check ($p.GUID -eq $script:fixtureGuid -and $p.Actions.Action -eq 'Primary') ('New unrelated GUID preview succeeds: '+$direction)
  $failed=$false;try{New-UserMigrationExecutionPreview $data ([guid]::NewGuid()) $temp}catch{$failed=$true};Check $failed 'Explicit wrong GUID rejected'
 }
 $g=[pscustomobject]@{Name='App';SID='S-1-5-21-111-222-333-1001';ObjectGUID=[guid]::NewGuid().ToString();Domain='source.test';DistinguishedName='CN=App,DC=source,DC=test';Scope='Universal';Category='Security';IsPrimary=$false}
 $mapping=[pscustomobject]@{SourceSID=$g.SID;Status='ConfiguredMapping';TargetSID='S-1-5-21-444-555-666-2001';TargetDN='CN=App,DC=target,DC=test';Approval='Reviewed fixture'}
 $policy=Get-ADMigrationPlanPolicy @($g) @($mapping)
 $action=@(New-UserMigrationActionPlan @($g) @($mapping) $policy (Get-ADDomain))
 Check ($action[0].RemoveAfterAdd -and -not $action[0].RemoveBeforeMove) 'Mapped shared source scheduled for removal only after replacement validation'
 $mapping.Status='ExactNameCandidate';$failed=$false;try{New-UserMigrationActionPlan @($g) @($mapping) (Get-ADMigrationPlanPolicy @($g) @($mapping)) (Get-ADDomain)}catch{$failed=$true};Check $failed 'Name-only suggestion cannot become an execution action'
 $g.Scope='Global';$g.SID='S-1-5-21-444-555-666-2001';$mapping.SourceSID=$g.SID;$mapping.Status='SameGroupRetentionReview';$mapping.TargetSID=$g.SID
 $action=@(New-UserMigrationActionPlan @($g) @($mapping) (Get-ADMigrationPlanPolicy @($g) @($mapping)) (Get-ADDomain));Check ($action[0].Action -eq 'Retain') 'Existing target-domain global group can be retained'
} $temp } finally {Remove-Module $m -Force;Remove-Item $temp -Recurse -Force}
