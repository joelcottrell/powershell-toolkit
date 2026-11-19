#Requires -Version 5.1
<#
.SYNOPSIS
    Synthetic mutation-adapter tests. Never contacts a directory.
.NOTES
    Author: Joel Cottrell | Version 1.0.13
#>
[CmdletBinding()]param()
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$module=@(Import-Module (Join-Path (Split-Path $PSScriptRoot -Parent) 'Modules/ADMigration.ADUserMigration.psm1') -Force -PassThru)
if ($module.Count -ne 1) {throw 'Ambiguous module import'}
$m=$module[0]
$temp=Join-Path ([IO.Path]::GetTempPath()) ('ADMigrationExecutionTests-'+[guid]::NewGuid())
[void][IO.Directory]::CreateDirectory($temp)
try { & $m { param($temp)
    $script:testCount=0
    function Assert-Test {param($Condition,$Message) if (-not $Condition) {throw "FAIL: $Message"};$script:testCount++;Write-Host "PASS: $Message"}
    function Expect-Throw {param([scriptblock]$Body,$Message) $threw=$false;try{& $Body}catch{$threw=$true};Assert-Test $threw $Message}
    $script:domains=@([pscustomobject]@{DNSRoot='source.example.test';RIDMaster='s.example.test';DistinguishedName='DC=source,DC=example,DC=test';DomainSID=[pscustomobject]@{Value='S-1-5-21-111-222-333'}},[pscustomobject]@{DNSRoot='target.example.test';RIDMaster='t.example.test';DistinguishedName='DC=target,DC=example,DC=test';DomainSID=[pscustomobject]@{Value='S-1-5-21-444-555-666'}})
    function New-TestAction {param($id,$action,$scope,$before,$after)
        [pscustomobject]@{Name="Fixture$id";SourceSID="S-1-5-21-111-222-333-$id";SourceGUID=[guid]::NewGuid().ToString();SourceDomain='source.example.test';SourceDN="CN=Fixture$id,DC=source,DC=example,DC=test";Scope=$scope;Category='Security';Action=$action;TargetSID=$(if($action -eq 'Omit'){''}elseif($action -eq 'Retain'){"S-1-5-21-111-222-333-$id"}else{"S-1-5-21-444-555-666-$id"});TargetDN="CN=Fixture$id,DC=target,DC=example,DC=test";RemoveBeforeMove=$before;RemoveAfterAdd=$after;Approval='Synthetic'}
    }
    $script:plan=[pscustomobject]@{GUID='11111111-2222-3333-4444-555555555555';Sam='FixtureUser';SourceDomain='source.example.test';TargetDomain='target.example.test';SourceRID='s.example.test';TargetRID='t.example.test';SourceDN='CN=Fixture\, User,DC=source,DC=example,DC=test';TargetOU='OU=Users,DC=target,DC=example,DC=test';SourceSID='S-1-5-21-111-222-333-9999';SIDHistory=@('S-1-5-21-777-888-999-1234');UPN='fixture@example.test';SourceUSN='123';InvariantAttributes=[pscustomobject]@{};Actions=@((New-TestAction 513 'Primary' 'Global' $false $false),(New-TestAction 1001 'Map' 'Global' $true $false),(New-TestAction 1002 'Map' 'Universal' $false $true),(New-TestAction 1003 'Map' 'Universal' $false $true),(New-TestAction 1004 'Omit' 'Global' $true $false),(New-TestAction 1005 'Retain' 'Universal' $false $false))}
    function Reset-Test {
        $script:moved=$false;$script:moveCalls=0;$script:failAdd='';$script:failRemove='';$script:failMove=$false;$script:uncertainMove=$false;$script:children=$false;$script:duplicate=$false;$script:loseHistory=$false;$script:drift=$false
        $script:members=@{};foreach($a in $script:plan.Actions){$script:members[$a.SourceSID]=$true}
        $script:events=New-Object 'System.Collections.Generic.List[string]'
        $script:ctx=[pscustomobject]@{Directory=$temp;StatePath=(Join-Path $temp 'state.json');State=[pscustomobject]@{MoveAttempted=$false;MoveVerified=$false;Status='Executing';Operator='Synthetic';LastStep='';UpdatedUtc='';Error=''}}
    }
    function Test-User {
        [pscustomobject]@{ObjectGUID=[guid]$script:plan.GUID;Enabled=$true;SamAccountName=$script:plan.Sam;UserPrincipalName=$script:plan.UPN;DistinguishedName=$(if($script:moved){'CN=Fixture\, User,'+$script:plan.TargetOU}else{$script:plan.SourceDN});SID=$(if($script:moved){'S-1-5-21-444-555-666-9999'}else{$script:plan.SourceSID});primaryGroupID=513;uSNChanged='123';SIDHistory=$(if($script:moved -and -not $script:loseHistory){@($script:plan.SourceSID)+@($script:plan.SIDHistory)}else{@($script:plan.SIDHistory)})}
    }
    function script:Get-ADUser {param($Identity,$Server,$Properties) Test-User}
    function script:Get-ADObject {param($Identity,$Properties,$SearchBase,$SearchScope,$LDAPFilter,$Server) if($Identity){Test-User;return};if($script:children){[pscustomobject]@{ObjectGUID=[guid]::NewGuid()}}}
    function script:Get-ADGroup {param($Identity,$Server,$LDAPFilter,$SearchBase,$SearchScope)
        if($LDAPFilter){$id=($script:plan.Actions | Where-Object { $_.SourceDN -eq $SearchBase -or $_.TargetDN -eq $SearchBase } | Select-Object -First 1);$sid=$(if($Server -eq $script:plan.TargetRID){$id.TargetSID}else{$id.SourceSID});if($script:members.ContainsKey($sid)){[pscustomobject]@{Name='Present'}};return}
        $a=@($script:plan.Actions | Where-Object { $_.SourceSID -eq $Identity -or $_.TargetSID -eq $Identity })[0]
        [pscustomobject]@{SID=$Identity;ObjectGUID=$a.SourceGUID;GroupScope=$a.Scope;GroupCategory=$a.Category;DistinguishedName=$(if($Identity -eq $a.TargetSID -and $a.Action -ne 'Retain'){$a.TargetDN}else{$a.SourceDN})}
    }
    function script:Add-ADGroupMember {param($Identity,$Members,$Server,$Confirm,$ErrorAction)
        if($Identity -eq $script:failAdd){throw 'Injected addition failure'};$script:members[$Identity]=$true;$script:events.Add('Add:'+ $Identity)
    }
    function script:Remove-ADGroupMember {param($Identity,$Members,$Server,$Confirm,$ErrorAction)
        if($Identity -eq $script:failRemove){throw 'Injected removal failure'};$script:members.Remove($Identity);$script:events.Add('Remove:'+ $Identity)
    }
    function script:Set-ADGroup {param($Identity,$Add,$Remove,$Server,$Confirm,$ErrorAction)
        $a=@($script:plan.Actions | Where-Object SourceDN -eq $Identity)[0]
        if ($Server -ne $script:plan.SourceRID) {throw 'Wrong distribution group endpoint'}
        $change=$Add;if($null -eq $change){$change=$Remove}
        if ($change.Count -ne 1 -or -not $change.ContainsKey('member') -or $change.member -ne (Test-User).DistinguishedName) {throw 'Wrong member-link update'}
        if($script:failAdd -eq $a.SourceSID){throw 'Injected distribution write failure'}
        if($Add){$script:members[$a.SourceSID]=$true}else{$script:members.Remove($a.SourceSID)}
        $script:events.Add('Distribution:'+ $a.SourceSID)
    }
    function script:Move-ADObject {param($Identity,$Server,$TargetServer,$TargetPath,$Confirm,$ErrorAction)
        $script:moveCalls++;$script:events.Add('Move');if($script:failMove){throw 'Injected move failure'}
        $script:moved=$true;$script:members.Remove('S-1-5-21-111-222-333-513');$script:members['S-1-5-21-444-555-666-513']=$true
        if($script:uncertainMove){throw 'Injected timeout after successful move'}
    }
    function script:Find-ADMigrationExecutionUser {param($GUID,$Domain)
        if($script:duplicate -or ($script:moved -and $Domain.DNSRoot -eq 'target.example.test') -or (-not $script:moved -and $Domain.DNSRoot -eq 'source.example.test')){Test-User}
    }
    function script:Get-ADMigrationExecutionMemberships {param($User,$Domains,$Domain)
        foreach($sid in $script:members.Keys){[pscustomobject]@{SID=$sid}}
        if($script:drift){[pscustomobject]@{SID='S-1-5-21-111-222-333-7777'}}
    }
    function script:Start-Sleep {param($Seconds)}
    Reset-Test
    Invoke-ADMigrationMoveSteps $script:ctx $script:plan $script:domains
    Assert-Test ($script:moveCalls -eq 1 -and $script:ctx.State.Status -eq 'ADVerifiedManualChecksPending') 'Reverse synthetic migration completes with one move'
    $ev=@($script:events.ToArray());$moveIndex=[array]::IndexOf($ev,'Move')
    Assert-Test ([array]::IndexOf($ev,'Remove:S-1-5-21-111-222-333-1001') -lt $moveIndex) 'Source global mapping removed before move'
    Assert-Test ([array]::IndexOf($ev,'Remove:S-1-5-21-111-222-333-1004') -lt $moveIndex) 'Approved omission removed before move'
    Assert-Test ([array]::IndexOf($ev,'Remove:S-1-5-21-111-222-333-1002') -gt [array]::IndexOf($ev,'Add:S-1-5-21-444-555-666-1003')) 'Both universal replacements added before either source removal'
    Assert-Test $script:members.ContainsKey('S-1-5-21-111-222-333-1005') 'Shared original group retained'
    Assert-Test (-not $script:members.ContainsKey('S-1-5-21-111-222-333-1004')) 'Omission has no replacement'
    Reset-Test;$script:failAdd='S-1-5-21-444-555-666-1003'
    Expect-Throw {Invoke-ADMigrationMoveSteps $script:ctx $script:plan $script:domains} 'Failed replacement stops execution'
    Assert-Test ($script:members.ContainsKey('S-1-5-21-111-222-333-1002') -and $script:members.ContainsKey('S-1-5-21-111-222-333-1003')) 'Failed addition preserves both source universal memberships'
    $script:failAdd='';Invoke-ADMigrationMoveSteps $script:ctx $script:plan $script:domains -Resume
    Assert-Test ($script:moveCalls -eq 1 -and $script:ctx.State.Status -eq 'ADVerifiedManualChecksPending') 'Post-move resume reconciles without a second move'
    # Reproduce a moved account missing its retained universal distribution group.
    $retained=$script:plan.Actions | Where-Object Action -eq 'Retain'
    $retained.Category='Distribution'
    $script:members.Remove($retained.SourceSID)
    $script:failAdd=$retained.SourceSID
    Expect-Throw {Invoke-ADMigrationMoveSteps $script:ctx $script:plan $script:domains -Resume} 'Rejected distribution write stops recovery'
    $script:failAdd=''
    Invoke-ADMigrationMoveSteps $script:ctx $script:plan $script:domains -Resume
    Assert-Test ($script:members.ContainsKey($retained.SourceSID) -and $script:moveCalls -eq 1) 'Distribution recovery restores exact membership without repeating move'
    $count=$script:events.Count
    Set-UserMigrationExecutionMembership $script:ctx (Test-User) $retained.SourceSID $script:domains[0] $true
    Assert-Test ($script:events.Count -eq $count) 'Already-present distribution membership produces no write'
    Set-UserMigrationExecutionMembership $script:ctx (Test-User) $retained.SourceSID $script:domains[0] $false
    Assert-Test (-not $script:members.ContainsKey($retained.SourceSID)) 'Distribution removal uses individual DN link'
    $retained.Category='Security'
    Reset-Test;$script:uncertainMove=$true
    Expect-Throw {Invoke-ADMigrationMoveSteps $script:ctx $script:plan $script:domains} 'Timeout after move stops without retry'
    Assert-Test ($script:ctx.State.MoveAttempted -and -not $script:ctx.State.MoveVerified -and $script:moveCalls -eq 1) 'Move intent persisted before uncertain outcome'
    $script:uncertainMove=$false;Invoke-ADMigrationMoveSteps $script:ctx $script:plan $script:domains -Resume
    Assert-Test ($script:moveCalls -eq 1) 'Recovery after timeout never moves again'
    Reset-Test;$script:failRemove='S-1-5-21-111-222-333-1001'
    Expect-Throw {Invoke-ADMigrationMoveSteps $script:ctx $script:plan $script:domains} 'Pre-move removal failure stops'
    Assert-Test ($script:moveCalls -eq 0) 'No move after failed preparation'
    Reset-Test;$script:children=$true
    Expect-Throw {Invoke-ADMigrationMoveSteps $script:ctx $script:plan $script:domains} 'Reappearing child blocks move'
    Assert-Test ($script:moveCalls -eq 0) 'No move with child objects'
    Reset-Test;$script:drift=$true
    Expect-Throw {Invoke-ADMigrationMoveSteps $script:ctx $script:plan $script:domains} 'Membership drift during preparation blocks move'
    Assert-Test ($script:moveCalls -eq 0) 'No move after membership drift'
    Reset-Test;$script:duplicate=$true
    Expect-Throw {Invoke-ADMigrationMoveSteps $script:ctx $script:plan $script:domains} 'Duplicate source/target GUID visibility blocks reconciliation'
    Assert-Test (@($script:events.ToArray() | Where-Object {$_ -like 'Add:*'}).Count -eq 0) 'No additions after ambiguous move'
    Reset-Test;$script:loseHistory=$true
    Expect-Throw {Invoke-ADMigrationMoveSteps $script:ctx $script:plan $script:domains} 'Missing previous SIDHistory blocks reconciliation'
    Reset-Test;$script:moved=$true;$u=Test-User;$u.SIDHistory=@($script:plan.SourceSID)
    Expect-Throw {Assert-ADMigrationMovedIdentity $script:plan $u $script:domains[1]} 'Pre-existing SIDHistory must also survive'
    $u=Test-User;$u.DistinguishedName='CN=Wrong,'+$script:plan.TargetOU
    Expect-Throw {Assert-ADMigrationMovedIdentity $script:plan $u $script:domains[1]} 'Wrong target RDN is rejected'
    $u=Test-User;$u.primaryGroupID=999
    Expect-Throw {Assert-ADMigrationMovedIdentity $script:plan $u $script:domains[1]} 'Wrong target primary group rejected'
    $saved=$script:plan.Actions;$script:plan.Actions=@($saved | Where-Object Action -in @('Primary','Retain'))
    Reset-Test;Invoke-ADMigrationMoveSteps $script:ctx $script:plan $script:domains
    Assert-Test ($script:moveCalls -eq 1 -and $script:events.Count -eq 1) 'Forward simple retention pilot requires no group mutations'
    $script:plan.Actions=$saved
    # Export a complete synthetic success report, then exercise partial-report handling.
    $script:plan | Add-Member AuditDirectory (Join-Path $temp 'before')
    $script:plan | Add-Member Ticket 'TEST-1'
    $script:plan | Add-Member Direction 'SYNTHETIC'
    [void][IO.Directory]::CreateDirectory($script:plan.AuditDirectory)
    Reset-Test
    Export-ADMigrationSnapshot @((Test-User)) (Join-Path $script:plan.AuditDirectory 'UserRawAttributes.clixml')
    Invoke-ADMigrationMoveSteps $script:ctx $script:plan $script:domains
    Export-ADMigrationExecutionReport $script:ctx $script:plan $script:domains
    $report=Read-ADMigrationExecutionJson (Join-Path $temp 'PostMigration.json')
    Assert-Test ($report.ObservationLocation -eq 'Target' -and $report.Groups.Count -eq 6 -and @($report.Attributes | Where-Object Changed).Count -gt 0) 'Full report contains observed target groups and attribute changes'
    Assert-Test (@($report.ManualChecks | Where-Object Status -ne 'NotVerified').Count -eq 0) 'Report never invents application or password success'
    Assert-Test ((Get-Item (Join-Path $temp 'PostMigration.html')).Length -gt 1000) 'Human-readable full report emitted'
    $script:duplicate=$true;$script:ctx.State.Status='StoppedReviewRequired'
    Export-ADMigrationExecutionReport $script:ctx $script:plan $script:domains
    $report=Read-ADMigrationExecutionJson (Join-Path $temp 'PostMigration.json')
    Assert-Test ($report.ObservationLocation -eq 'Unknown' -and $report.State.Status -eq 'StoppedReviewRequired') 'Ambiguous outcome still produces partial report'
    $u=Test-User;$script:plan.InvariantAttributes=[pscustomobject]@{employeeID=@('synthetic-100')}
    Expect-Throw {Assert-ADMigrationInvariantAttributes $script:plan $u} 'Missing preserved employee attribute blocks validation'
    $script:plan.InvariantAttributes=[pscustomobject]@{}
    # Exercise the real ShouldProcess gate before security checks or mutation adapters.
    function script:Assert-ADMigrationPlanIntegrity {param($Plan,$InputData,$ExpectedUserGUID)}
    $script:plan | Add-Member CreatedUtc ([datetime]::UtcNow.ToString('o'))
    $path=Join-Path $temp 'plan.json';Write-ADMigrationJson $script:plan $path
    Reset-Test;Invoke-ADMigrationExecution -InputData @{} -ExpectedUserGUID ([guid]$script:plan.GUID) -PlanPath $path -OutputRoot $temp -WhatIf
    Assert-Test ($script:moveCalls -eq 0 -and $script:events.Count -eq 0) 'WhatIf cannot reach any mutation'
    Write-Host "All $script:testCount execution assertions passed. Synthetic AD only."
} $temp } finally {Remove-Module $m -Force;Remove-Item $temp -Recurse -Force}
