#Requires -Version 5.1
<#
.SYNOPSIS
    Explicit single-account execution, journal and post-move recovery.
.NOTES
    Author: Joel Cottrell
    Version: 1.0.13 | 2026-11-13
    No automatic rollback or repeated Move-ADObject after an uncertain result.
#>
function Read-ADMigrationExecutionJson { param([string]$Path) Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json }
function Get-ADMigrationSetKey { param([object[]]$Values) (@($Values | ForEach-Object { ([string]$_).ToLowerInvariant() } | Sort-Object -Unique) -join '|') }
function Get-ADMigrationPlanPolicy {
    param($Groups,$Mappings)
    # Approval occurs when the administrator reviews and confirms the saved execution plan.
    [pscustomobject]@{
        GroupSIDs=@($Groups | ForEach-Object SID)
        Mappings=@($Mappings | Where-Object Status -eq 'ConfiguredMapping' | ForEach-Object { [pscustomobject]@{Source=$_.SourceSID;Target=$_.TargetSID} })
        Omit=@($Mappings | Where-Object Status -eq 'ConfiguredOmit' | ForEach-Object SourceSID)
        RemoveAfterAdd=@($Groups | Where-Object { $_.Scope -ne 'Global' -and $_.SID -in @($Mappings | Where-Object Status -eq 'ConfiguredMapping' | ForEach-Object SourceSID) } | ForEach-Object SID)
    }
}
function New-UserMigrationActionPlan {
    param($Groups,$Mappings,$Approval,$Target)
    if ((Get-ADMigrationSetKey @($Groups.SID)) -ne (Get-ADMigrationSetKey @($Approval.GroupSIDs))) { throw 'Account memberships changed since reviewed evidence. Review a new audit before execution.' }
    $actions=@(foreach ($g in $Groups) {
        $m=@($Mappings | Where-Object SourceSID -eq $g.SID)
        if ($m.Count -ne 1) { throw 'Missing or ambiguous group disposition.' }; $m=$m[0]
        $action='Retain';$sid=$g.SID;$removeBefore=$false;$removeAfter=$false
        if ([string]$g.IsPrimary -eq 'True') {
            if ($g.SID -notmatch '-513$') { throw 'Non-default primary group is not supported.' }
            $action='Primary'; $sid=$Target.DomainSID.Value+'-513'
        } elseif ($m.Status -eq 'ConfiguredMapping') {
            $match=@($Approval.Mappings | Where-Object { $_.Source -eq $g.SID -and $_.Target -eq $m.TargetSID })
            if ($match.Count -ne 1) { throw 'Mapping differs from the reviewed account approval.' }
            $action='Map';$sid=$m.TargetSID
            $removeBefore=$g.Scope -eq 'Global'
            $removeAfter=@($Approval.RemoveAfterAdd) -contains $g.SID
            if (-not $removeBefore -and -not $removeAfter) { throw 'Mapped shared group lacks an explicit source-membership disposition.' }
        } elseif ($m.Status -eq 'ConfiguredOmit') {
            if (@($Approval.Omit) -notcontains $g.SID -or $g.Scope -ne 'Global') { throw 'Omission is not approved for this account.' }
            $action='Omit';$sid='';$removeBefore=$true
        } elseif ($m.Status -notin @('SameGroupRetentionReview','ConfiguredRetain')) { throw ('Unresolved group: '+$g.Name) }
        if ($action -eq 'Retain' -and $g.Scope -eq 'Global' -and -not $g.SID.StartsWith($Target.DomainSID.Value+'-')) { throw 'Unexpected retained global membership. Review required.' }
        [pscustomobject]@{Name=$g.Name;SourceSID=$g.SID;SourceGUID=$g.ObjectGUID;SourceDomain=$g.Domain;SourceDN=$g.DistinguishedName;Scope=$g.Scope;Category=$g.Category;Action=$action;TargetSID=$sid;TargetDN=$m.TargetDN;RemoveBeforeMove=$removeBefore;RemoveAfterAdd=$removeAfter;Approval=$m.Approval}
    })
    return $actions
}
function New-UserMigrationExecutionPreview {
    [CmdletBinding()]
    param($InputData,[guid]$ExpectedUserGUID,[string]$OutputRoot)
    $audit=Invoke-ADMigrationAudit -InputData $InputData -OutputRoot $OutputRoot
    if ($audit.Status -eq 'Blocked') { throw ('Fresh audit is blocked: '+$audit.Directory) }
    $pre=Read-ADMigrationExecutionJson (Join-Path $audit.Directory 'PreMigration.json')
    $summary=Read-ADMigrationExecutionJson (Join-Path $audit.Directory 'UserSummary.json')
    if ($ExpectedUserGUID -eq [guid]::Empty) { $ExpectedUserGUID=[guid]$pre.State.SourceGUID }
    $approval=Get-ADMigrationPlanPolicy $pre.Groups $pre.GroupMappings
    if ([string]$pre.State.SourceGUID -ne $ExpectedUserGUID.ToString()) { throw 'Source GUID does not match the expected account.' }
    $target=Get-ADDomain -Identity $InputData.Direction.TargetDomain -Server $pre.TargetRIDMaster
    $actions=@(New-UserMigrationActionPlan $pre.Groups $pre.GroupMappings $approval $target)
    $invariants=[ordered]@{}
    foreach ($field in @('employeeID','mail','proxyAddresses','pwdLastSet','userAccountControl','homeDirectory','homeDrive','profilePath','department','company','manager','telephoneNumber','mobile')+(1..15 | ForEach-Object { 'extensionAttribute'+$_ })) { $invariants[$field]=@($summary.$field) }
    $plan=[ordered]@{SchemaVersion=1;InvariantAttributes=$invariants;Version='1.0.13';CreatedUtc=[datetime]::UtcNow.ToString('o');GUID=$ExpectedUserGUID.ToString();Sam=$InputData.Row.SamAccountName;Ticket=$InputData.Row.ChangeReference;Direction=$InputData.Row.MigrationDirection;SourceDomain=$InputData.Direction.SourceDomain;TargetDomain=$InputData.Direction.TargetDomain;SourceRID=$pre.SourceRIDMaster;TargetRID=$pre.TargetRIDMaster;TargetOU=$InputData.Row.TargetOU;SourceDN=[string]$summary.DistinguishedName[0];SourceSID=[string]$summary.SID[0];SIDHistory=@($summary.SIDHistory);SourceUSN=[string]$summary.uSNChanged[0];UPN=[string]$summary.UserPrincipalName[0];CsvHash=$InputData.CsvHash;ConfigHash=$InputData.ConfigHash;MapHash=$InputData.MapHash;AuditDirectory=[IO.Path]::GetFullPath($audit.Directory);AuditManifestHash=(Get-ADMigrationHash (Join-Path $audit.Directory 'EvidenceHashes.json'));Actions=$actions;ManualChecks='Password sign-in, application access, home-drive, Change tracking and temporary admin access remain manual.'}
    $path=Join-Path $audit.Directory 'ExecutionPlan.json';Write-ADMigrationJson $plan $path
    $actions | Export-Csv (Join-Path $audit.Directory 'ExecutionActions.csv') -NoTypeInformation -Encoding UTF8
    $body='<h1>AD user migration execution preview</h1><p>No account move or membership changes performed.</p><p>Order: remove listed non-primary globals; move once; verify identity; add and verify ALL replacements; remove listed mapped source memberships; reconcile retained memberships; report.</p>'
    $body+='<h2>Identity and target</h2>'+($summary | ConvertTo-Html -Fragment | Out-String)
    $body+='<h2>Operator</h2>'+($pre.Operator | ConvertTo-Html -Fragment | Out-String)
    $body+='<h2>Original groups</h2>'+($pre.Groups | ConvertTo-Html -Fragment | Out-String)
    $body+='<h2>Approved actions</h2>'+($actions | ConvertTo-Html -Fragment | Out-String)
    $body+='<h2>Findings and visible children</h2>'+($pre.Findings | ConvertTo-Html -Fragment | Out-String)+($pre.ChildObjects | ConvertTo-Html -Fragment | Out-String)
    $raw=Read-ADMigrationExecutionJson (Join-Path $audit.Directory 'UserRawAttributes.json')
    $attributes=@(foreach ($p in $raw.Items[0].Attributes.PSObject.Properties) { [pscustomobject]@{Attribute=$p.Name;Value=(ConvertTo-Json -InputObject $p.Value -Depth 24 -Compress)} })
    $body+='<h2>All readable source attributes</h2>'+($attributes | ConvertTo-Html -Fragment | Out-String)
    $body+='<p>Historical ActiveSync deletion evidence is separate. No children are deleted by this entry point. Manual runbook tasks require operator verification.</p>'
    ConvertTo-Html -Title 'Execution preview' -Body $body | Set-Content (Join-Path $audit.Directory 'ExecutionPreview.html') -Encoding UTF8
    [pscustomobject]@{Status='PreviewOnly';PlanPath=[IO.Path]::GetFullPath($path);Directory=$audit.Directory}
}
function Assert-ADMigrationPlanIntegrity {
    param($Plan,$InputData,[guid]$ExpectedUserGUID,[switch]$AllowPreviousResume)
    if ($Plan.SourceDomain -ne $InputData.Direction.SourceDomain -or $Plan.TargetDomain -ne $InputData.Direction.TargetDomain) { throw 'Plan domain direction mismatch.' }
    if ($Plan.Version -ne '1.0.13' -or $Plan.GUID -ne $ExpectedUserGUID.ToString() -or $Plan.Sam -ne $InputData.Row.SamAccountName -or $Plan.Ticket -ne $InputData.Row.ChangeReference -or $Plan.Direction -ne $InputData.Row.MigrationDirection -or $Plan.TargetOU -ne $InputData.Row.TargetOU) { throw 'Plan version/identity/input mismatch. Use the original release for older execution recovery.' }
    foreach ($key in @('CsvHash','ConfigHash','MapHash')) { if ($Plan.$key -ne $InputData.$key) { throw "Plan $key changed. Generate a new preview." } }
    $manifestPath=Join-Path $Plan.AuditDirectory 'EvidenceHashes.json'
    if ((Get-ADMigrationHash $manifestPath) -ne $Plan.AuditManifestHash) { throw 'Audit manifest changed.' }
    # Windows PowerShell 5.1 can emit a JSON array as one pipeline object.
    # Assign first, then enumerate its records instead of wrapping pipeline output.
    $manifest = Read-ADMigrationExecutionJson $manifestPath
    foreach ($f in $manifest) {
        if ($f.FileName -isnot [string] -or $f.SHA256 -isnot [string]) { throw 'Invalid evidence manifest record: scalar filename and SHA256 required.' }
        if ([IO.Path]::GetFileName($f.FileName) -ne $f.FileName) { throw 'Invalid evidence filename.' }
        if ((Get-ADMigrationHash (Join-Path $Plan.AuditDirectory $f.FileName)) -ne $f.SHA256) { throw ('Audit evidence changed: '+$f.FileName) }
    }
    $pre=Read-ADMigrationExecutionJson (Join-Path $Plan.AuditDirectory 'PreMigration.json')
    $summary=Read-ADMigrationExecutionJson (Join-Path $Plan.AuditDirectory 'UserSummary.json')
    foreach ($pair in @(@('GUID','ObjectGUID'),@('SourceDN','DistinguishedName'),@('SourceSID','SID'),@('SourceUSN','uSNChanged'),@('UPN','UserPrincipalName'))) { if ($Plan.($pair[0]) -ne [string]$summary.($pair[1])[0]) { throw 'Plan source attributes differ from baseline.' } }
    foreach ($field in @($Plan.InvariantAttributes.PSObject.Properties | ForEach-Object Name)) { if ((Get-ADMigrationSetKey @($Plan.InvariantAttributes.$field)) -ne (Get-ADMigrationSetKey @($summary.$field))) { throw 'Plan invariant differs from audit.' } }
    $target=[pscustomobject]@{DomainSID=[pscustomobject]@{Value=($Plan.Actions | Where-Object Action -eq 'Primary' | Select-Object -ExpandProperty TargetSID) -replace '-513$',''}}
    $approval=Get-ADMigrationPlanPolicy $pre.Groups $pre.GroupMappings
    $expected=@(New-UserMigrationActionPlan $pre.Groups $pre.GroupMappings $approval $target)
    if (($expected | ConvertTo-Json -Depth 10 -Compress) -ne ($Plan.Actions | ConvertTo-Json -Depth 10 -Compress)) { throw 'Execution actions differ from approved audit.' }
}
function Get-ADMigrationExecutionDomains {
    param($Plan,[string]$ForestRoot)
    $forest=Get-ADForest -Server $ForestRoot -ErrorAction Stop
    if ($forest.RootDomain -ne $ForestRoot) { throw 'Unexpected forest root.' }
    $domains=@(foreach ($dns in $forest.Domains) { Get-ADDomain -Identity $dns -Server $dns })
    foreach ($pair in @(@($Plan.SourceDomain,$Plan.SourceRID),@($Plan.TargetDomain,$Plan.TargetRID))) {
        $d=@($domains | Where-Object DNSRoot -eq $pair[0])
        if ($d.Count -ne 1 -or $d[0].RIDMaster -ne $pair[1]) { throw 'RID Master changed. Stop and review a new plan.' }
        $dc=Get-ADDomainController -Identity $pair[1] -Server $pair[0]
        if ($dc.IsReadOnly -or @($dc.OperationMasterRoles) -notcontains 'RIDMaster') { throw 'Invalid writable RID endpoint.' }
    }
    $domains
}
function Find-ADMigrationExecutionUser {
    param([guid]$GUID,$Domain)
    $filter=($GUID.ToByteArray() | ForEach-Object { '\{0:x2}' -f $_ }) -join ''
    # Search NC explicitly: source referral is never treated as proof of absence.
    @(Get-ADUser -LDAPFilter "(objectGUID=$filter)" -SearchBase $Domain.DistinguishedName -Server $Domain.RIDMaster -Properties *)
}
function Write-ADMigrationExecutionEvent {
    param($Context,[string]$Step,[string]$Status,[string]$Detail)
    $event=[pscustomobject]@{Utc=[datetime]::UtcNow.ToString('o');Step=$Step;Status=$Status;Detail=$Detail;Operator=$Context.State.Operator}
    $event | ConvertTo-Json -Compress | Add-Content (Join-Path $Context.Directory 'Execution.jsonl') -Encoding UTF8
    $Context.State.LastStep=$Step;$Context.State.UpdatedUtc=$event.Utc
    Write-ADMigrationJson $Context.State $Context.StatePath
    Write-Host "[$Status] $Step : $Detail"
}
function Get-ADMigrationExecutionMemberships { param($User,$Domains,$Domain) @(Get-ADMigrationDirectGroups $User $Domains $Domain) }
function Test-ADMigrationDirectMembership {
    param($User,$Group,$Domain)
    $member=ConvertTo-ADMigrationLdapValue $User.DistinguishedName
    $hits=@(Get-ADGroup -Identity $Group -Server $Domain.RIDMaster)
    if ($hits.Count -ne 1) { throw 'Group identity resolution failed.' }
    $match=@(Get-ADGroup -LDAPFilter "(member=$member)" -SearchBase $hits[0].DistinguishedName -SearchScope Base -Server $Domain.RIDMaster)
    return ($match.Count -eq 1)
}
function Set-UserMigrationExecutionMembership {
    param($Context,$User,[string]$SID,$Domain,[bool]$Present)
    $group=Get-ADGroup -Identity $SID -Server $Domain.RIDMaster
    if ([string]$group.SID -ne $SID) { throw 'Resolved group SID mismatch.' }
    $current=Test-ADMigrationDirectMembership $User $SID $Domain
    if ($current -eq $Present) { Write-ADMigrationExecutionEvent $Context 'Membership' 'AlreadyCorrect' "$SID present=$Present";return }
    Write-ADMigrationExecutionEvent $Context 'Membership' 'Pending' "$SID present=$Present on $($Domain.RIDMaster)"
    if ([string]$group.GroupCategory -eq 'Distribution') {
        # Incremental member-link update. Never replace the member list or convert group type.
        if ([string]::IsNullOrWhiteSpace([string]$group.DistinguishedName) -or [string]::IsNullOrWhiteSpace([string]$User.DistinguishedName)) { throw 'Distribution membership requires resolved group and user DNs.' }
        Write-ADMigrationExecutionEvent $Context 'MembershipMethod' 'Selected' 'Distribution group: incremental member DN update on owning RID endpoint.'
        if ($Present) { Set-ADGroup -Identity $group.DistinguishedName -Add @{member=[string]$User.DistinguishedName} -Server $Domain.RIDMaster -Confirm:$false -ErrorAction Stop }
        else { Set-ADGroup -Identity $group.DistinguishedName -Remove @{member=[string]$User.DistinguishedName} -Server $Domain.RIDMaster -Confirm:$false -ErrorAction Stop }
    }
    elseif ($Present) { Add-ADGroupMember -Identity $SID -Members $User -Server $Domain.RIDMaster -Confirm:$false -ErrorAction Stop }
    else { Remove-ADGroupMember -Identity $SID -Members $User -Server $Domain.RIDMaster -Confirm:$false -ErrorAction Stop }
    if ((Test-ADMigrationDirectMembership $User $SID $Domain) -ne $Present) { throw "Membership write could not be verified: $SID" }
    Write-ADMigrationExecutionEvent $Context 'Membership' 'Verified' "$SID present=$Present"
}
function Assert-ADMigrationPasswordTimestamp {
    param($Before,$After)
    $b=@($Before);$a=@($After)
    if ($b.Count -ne 1 -or $a.Count -ne 1) { throw 'pwdLastSet must be a single integer before and after the move.' }
    $old=[long]0;$new=[long]0
    if (-not [long]::TryParse([string]$b[0],[ref]$old) -or -not [long]::TryParse([string]$a[0],[ref]$new)) { throw 'Invalid pwdLastSet integer.' }
    if ($old -eq 0 -and $new -eq 0) {return}
    if ($old -le 0 -or $new -le 0 -or $new -lt $old) {throw 'Unexpected pwdLastSet transition or must-change state.'}
    $time=[datetime]::FromFileTimeUtc($new)
    if ($time -gt [datetime]::UtcNow.AddMinutes(5)) {throw 'pwdLastSet is unexpectedly in the future.'}
    # MS-DRSR IDL_DRSInterDomainMove transforms nonzero pwdLastSet to -1.
    # Observe and report the resulting timestamp; never write it or infer password sign-in success.
}
function Assert-ADMigrationInvariantAttributes {
    param($Plan,$User,[switch]$AfterMove)
    foreach ($field in @($Plan.InvariantAttributes.PSObject.Properties | ForEach-Object Name)) {
        $actual=@(Get-ADMigrationOptionalProperty $User $field | ForEach-Object { [string]$_ })
        if ($AfterMove -and $field -eq 'pwdLastSet') { Assert-ADMigrationPasswordTimestamp $Plan.InvariantAttributes.$field $actual; continue }
        $expected=@($Plan.InvariantAttributes.$field | Where-Object { $null -ne $_ -and [string]$_ -ne '' })
        $actual=@($actual | Where-Object { $null -ne $_ -and [string]$_ -ne '' })
        if ((Get-ADMigrationSetKey $actual) -ne (Get-ADMigrationSetKey $expected)) { throw ('Preserved attribute differs: '+$field) }
    }
}
function Assert-ADMigrationMovedIdentity {
    param($Plan,$User,$Target)
    if ([string]$User.ObjectGUID -ne $Plan.GUID -or -not $User.Enabled -or $User.SamAccountName -ne $Plan.Sam -or [string]$User.UserPrincipalName -ne $Plan.UPN) { throw 'Post-move GUID/enabled/SAM/UPN mismatch.' }
    $expectedDN=($Plan.SourceDN -split '(?<!\\),',2)[0]+','+$Plan.TargetOU
    if ($User.DistinguishedName -ne $expectedDN) { throw 'Post-move target DN mismatch.' }
    if ([string]$User.SID -eq $Plan.SourceSID -or -not ([string]$User.SID).StartsWith($Target.DomainSID.Value+'-') -or [int]$User.primaryGroupID -ne 513) { throw 'Target SID/primary group validation failed.' }
    Assert-ADMigrationInvariantAttributes $Plan $User -AfterMove
    $history=@($User.SIDHistory | ForEach-Object { [string]$_ })
    foreach ($sid in @($Plan.SourceSID)+@($Plan.SIDHistory)) { if ($history -notcontains $sid) { throw "Expected SIDHistory absent: $sid" } }
}
function Invoke-ADMigrationMoveSteps {
    param($Context,$Plan,$Domains,[switch]$Resume)
    $source=@($Domains | Where-Object DNSRoot -eq $Plan.SourceDomain)[0]
    $target=@($Domains | Where-Object DNSRoot -eq $Plan.TargetDomain)[0]
    if (-not $Resume) {
        $user=Get-ADUser -Identity ([guid]$Plan.GUID) -Server $Plan.SourceRID -Properties *
        if ([string]$user.ObjectGUID -ne $Plan.GUID -or [string]$user.SID -ne $Plan.SourceSID -or $user.DistinguishedName -ne $Plan.SourceDN -or [string]$user.uSNChanged -ne $Plan.SourceUSN -or -not $user.Enabled -or $user.SamAccountName -ne $Plan.Sam -or $user.UserPrincipalName -ne $Plan.UPN) { throw 'Source identity/state changed immediately before preparation.' }
        Assert-ADMigrationInvariantAttributes $Plan $user
        $initialGroups=@(Get-ADMigrationExecutionMemberships $user $Domains $source)
        if ((Get-ADMigrationSetKey $initialGroups.SID) -ne (Get-ADMigrationSetKey @($Plan.Actions.SourceSID))) { throw 'Membership drift immediately before preparation.' }
        foreach ($a in @($Plan.Actions | Where-Object RemoveBeforeMove)) {
            Set-UserMigrationExecutionMembership $Context $user $a.SourceSID $source $false
        }
        $beforeMove=@(Get-ADMigrationExecutionMemberships $user $Domains $source)
        $expected=@($Plan.Actions | Where-Object { -not $_.RemoveBeforeMove } | ForEach-Object SourceSID)
        if ((Get-ADMigrationSetKey $beforeMove.SID) -ne (Get-ADMigrationSetKey $expected)) { throw 'Group drift during preparation. No move attempted; review the journal.' }
        $children=@(Get-ADObject -SearchBase $user.DistinguishedName -SearchScope OneLevel -LDAPFilter '(objectClass=*)' -Server $Plan.SourceRID)
        if ($children.Count) { throw 'Child objects appeared. No move attempted.' }
        $Context.State.MoveAttempted=$true
        Write-ADMigrationExecutionEvent $Context 'Move' 'Pending' 'Move-ADObject will be called once. Any uncertain result requires explicit recovery.'
        Move-ADObject -Identity ([guid]$Plan.GUID) -Server $Plan.SourceRID -TargetServer $Plan.TargetRID -TargetPath $Plan.TargetOU -Confirm:$false -ErrorAction Stop
        Write-ADMigrationExecutionEvent $Context 'Move' 'CommandReturned' 'Waiting for source absence and target GUID on pinned RID Masters.'
    }
    $moved=$null
    for ($i=0;$i -lt 30;$i++) {
        $s=@(Find-ADMigrationExecutionUser ([guid]$Plan.GUID) $source);$t=@(Find-ADMigrationExecutionUser ([guid]$Plan.GUID) $target)
        if ($s.Count -gt 1 -or $t.Count -gt 1 -or ($s.Count -and $t.Count)) { throw 'Ambiguous GUID visibility. Stop; do not retry the move or delete either object.' }
        if ($s.Count -eq 0 -and $t.Count -eq 1) { $moved=$t[0];break }
        Start-Sleep -Seconds 2
    }
    if ($null -eq $moved) { throw 'Move outcome not verified on RID Masters. No automatic move retry.' }
    Assert-ADMigrationMovedIdentity $Plan $moved $target
    $Context.State.MoveVerified=$true
    Write-ADMigrationExecutionEvent $Context 'PasswordTimestamp' 'Observed' ('pwdLastSet after move='+[string](Get-ADMigrationOptionalProperty $moved 'pwdLastSet')+'; cross-domain timestamp transformation permitted; password sign-in remains unverified.')
    Write-ADMigrationExecutionEvent $Context 'Move' 'Verified' 'GUID, source absence, target DN/SID/primary, existing SIDHistory, SAM, UPN and enabled state verified.'
    # Validate every target before any post-move addition or source universal removal.
    foreach ($a in @($Plan.Actions | Where-Object Action -eq 'Map')) {
        $g=Get-ADGroup -Identity $a.TargetSID -Server $Plan.TargetRID
        if ([string]$g.SID -ne $a.TargetSID -or [string]$g.GroupCategory -ne $a.Category -or $g.DistinguishedName -ne $a.TargetDN) { throw 'Target mapping identity/category/DN drift.' }
        Set-UserMigrationExecutionMembership $Context $moved $a.TargetSID $target $true
    }
    foreach ($a in @($Plan.Actions | Where-Object Action -eq 'Map')) {
        if (-not (Test-ADMigrationDirectMembership $moved $a.TargetSID $target)) { throw 'Replacement membership missing; mapped source memberships will not be removed.' }
    }
    # Approved mapped shared sources are removed only after ALL replacements verify.
    foreach ($a in @($Plan.Actions | Where-Object RemoveAfterAdd)) { Set-UserMigrationExecutionMembership $Context $moved $a.SourceSID $source $false }
    foreach ($a in @($Plan.Actions | Where-Object Action -eq 'Retain')) {
        $d=@($Domains | Where-Object DNSRoot -eq $a.SourceDomain)[0]
        $g=Get-ADGroup -Identity $a.SourceSID -Server $d.RIDMaster
        if ([string]$g.ObjectGUID -ne $a.SourceGUID -or [string]$g.GroupScope -ne $a.Scope -or [string]$g.GroupCategory -ne $a.Category) { throw 'Retained group identity or scope drift.' }
        Set-UserMigrationExecutionMembership $Context $moved $a.SourceSID $d $true
    }
    $moved=Get-ADUser -Identity ([guid]$Plan.GUID) -Server $Plan.TargetRID -Properties *
    Assert-ADMigrationMovedIdentity $Plan $moved $target
    $after=@(Get-ADMigrationExecutionMemberships $moved $Domains $target)
    $expected=@($Plan.Actions | Where-Object Action -ne 'Omit' | ForEach-Object TargetSID)
    if ((Get-ADMigrationSetKey $after.SID) -ne (Get-ADMigrationSetKey $expected)) { throw 'Final membership set differs from approved result. Review post-migration evidence.' }
    $children=@(Get-ADObject -SearchBase $moved.DistinguishedName -SearchScope OneLevel -LDAPFilter '(objectClass=*)' -Server $Plan.TargetRID)
    if ($children.Count) { throw 'Post-move child objects present; review required.' }
    $Context.State.Status='ADVerifiedManualChecksPending'
    Write-ADMigrationExecutionEvent $Context 'FinalValidation' 'Verified' 'Expected direct/primary groups and no visible children verified. Password/application tests remain manual.'
}
function Export-ADMigrationExecutionReport {
    param($Context,$Plan,$Domains)
    $checks=New-Object 'System.Collections.Generic.List[object]'
    $groups=@();$children=@();$attributeChanges=@();$observed='Unknown'
    try {
        $source=@($Domains | Where-Object DNSRoot -eq $Plan.SourceDomain)[0];$target=@($Domains | Where-Object DNSRoot -eq $Plan.TargetDomain)[0]
        $s=@(Find-ADMigrationExecutionUser ([guid]$Plan.GUID) $source);$t=@(Find-ADMigrationExecutionUser ([guid]$Plan.GUID) $target)
        $checks.Add([pscustomobject]@{Check='GUID visibility on source/target RID Masters';Result="Source=$($s.Count); Target=$($t.Count)"})
        if ($s.Count -eq 1 -and $t.Count -eq 0) { $u=$s[0];$d=$source;$observed='Source' }
        elseif ($s.Count -eq 0 -and $t.Count -eq 1) { $u=$t[0];$d=$target;$observed='Target' }
        else { throw 'Identity location unresolved; no guessed post-state.' }
        Export-ADMigrationSnapshot @($u) (Join-Path $Context.Directory 'AfterUser.clixml')
        $raw=Get-ADObject -Identity ([guid]$Plan.GUID) -Server $d.RIDMaster -Properties *
        Export-ADMigrationSnapshot @($raw) (Join-Path $Context.Directory 'AfterRawAttributes.clixml')
        $groups=@(Get-ADMigrationExecutionMemberships $u $Domains $d)
        $children=@(Get-ADObject -SearchBase $u.DistinguishedName -SearchScope Subtree -LDAPFilter '(objectClass=*)' -Server $d.RIDMaster -Properties * | Where-Object { [string]$_.ObjectGUID -ne $Plan.GUID })
        Export-ADMigrationSnapshot $children (Join-Path $Context.Directory 'AfterChildren.clixml')
        $before=Read-ADMigrationExecutionJson (Join-Path $Plan.AuditDirectory 'UserRawAttributes.json')
        $after=Read-ADMigrationExecutionJson (Join-Path $Context.Directory 'AfterRawAttributes.json')
        $b=$before.Items[0].Attributes;$a=$after.Items[0].Attributes
        $names=@(@($b.PSObject.Properties.Name)+@($a.PSObject.Properties.Name) | Sort-Object -Unique)
        $attributeChanges=@(foreach ($name in $names) {
            $bv=Get-ADMigrationOptionalProperty $b $name;$av=Get-ADMigrationOptionalProperty $a $name
            $bs=ConvertTo-Json -InputObject $bv -Depth 24 -Compress;$as=ConvertTo-Json -InputObject $av -Depth 24 -Compress
            [pscustomobject]@{Attribute=$name;Before=$bs;After=$as;Changed=($bs -cne $as);Review=$(if ($bs -cne $as) {'Review observed difference; not automatically approved'} else {'Unchanged'})}
        })
        $checks.Add([pscustomobject]@{Check='Post-state capture';Result='Complete readable attributes, memberships and visible descendants'})
    } catch { $checks.Add([pscustomobject]@{Check='Post-state capture';Result=('Incomplete: '+$_.Exception.Message)});if ($Context.State.Status -eq 'ADVerifiedManualChecksPending') {$Context.State.Status='ADVerifiedReportIncomplete'} }
    $comparison=@(foreach ($a in $Plan.Actions) {
        [pscustomobject]@{SourceName=$a.Name;SourceSID=$a.SourceSID;Disposition=$a.Action;ExpectedSID=$a.TargetSID;SourcePresent=(@($groups | ForEach-Object SID) -contains $a.SourceSID);ExpectedPresent=([bool]$a.TargetSID -and @($groups | ForEach-Object SID) -contains $a.TargetSID);RemoveBeforeMove=$a.RemoveBeforeMove;RemoveAfterAdd=$a.RemoveAfterAdd;ObservationLocation=$observed}
    })
    Export-ADMigrationCsv $groups (Join-Path $Context.Directory 'AfterGroups.csv') @('Name','SID','Domain','Scope','Category','IsPrimary')
    Export-ADMigrationCsv $comparison (Join-Path $Context.Directory 'GroupResults.csv') @('SourceName','SourceSID','Disposition','ExpectedSID','SourcePresent','ExpectedPresent','ObservationLocation')
    Export-ADMigrationCsv $attributeChanges (Join-Path $Context.Directory 'AttributeComparison.csv') @('Attribute','Before','After','Changed','Review')
    $events=@();$eventPath=Join-Path $Context.Directory 'Execution.jsonl'
    if (Test-Path $eventPath) { $events=@(Get-Content $eventPath -Encoding UTF8 | ForEach-Object { $_ | ConvertFrom-Json }) }
    $manual=@('Password sign-in','Application access where applicable','home-drive workflow','Change and stakeholder follow-up','Temporary Enterprise Admin / Protected Users restoration per approved runbook')
    $report=[ordered]@{Version='1.0.13';State=$Context.State;ObservationLocation=$observed;Plan=$Plan;Checks=@($checks.ToArray());Steps=$events;Groups=$comparison;Attributes=$attributeChanges;VisibleChildren=$children.Count;ManualChecks=@($manual | ForEach-Object { [pscustomobject]@{Check=$_;Status='NotVerified'} });Limits='RID endpoint observations only; no forest-wide convergence, password sign-in or application validation claim. No account recreation or automatic rollback.'}
    Write-ADMigrationJson $report (Join-Path $Context.Directory 'PostMigration.json')
    $body='<h1>AD user migration execution report</h1>'
    $body+=($Context.State | ConvertTo-Html -Fragment | Out-String)
    $body+='<h2>Identity and capture checks</h2>'+($checks.ToArray() | ConvertTo-Html -Fragment | Out-String)
    $body+='<h2>Steps and timings</h2>'+($events | ConvertTo-Html -Fragment | Out-String)
    $body+='<h2>Group results</h2>'+($comparison | ConvertTo-Html -Fragment | Out-String)
    $body+='<h2>All readable attributes, before and after</h2>'+($attributeChanges | ConvertTo-Html -Fragment | Out-String)
    $body+='<h2>Manual checks</h2>'+($report.ManualChecks | ConvertTo-Html -Fragment | Out-String)
    $body+='<p>Before audit is preserved under BeforeAudit. Historical child deletion evidence must be retained with the ticket. This run does not delete children. AfterChildren.json records current visible descendants.</p>'
    ConvertTo-Html -Title 'AD user migration execution report' -Head '<meta charset="utf-8"><style>body{font:14px Segoe UI;margin:24px}table{border-collapse:collapse;width:100%}td,th{border:1px solid #ccc;padding:6px;overflow-wrap:anywhere}th{background:#e7eff8}</style>' -Body $body | Set-Content (Join-Path $Context.Directory 'PostMigration.html') -Encoding UTF8
    @"
Change tracking: $($Plan.Ticket)
User: $($Plan.Sam)
Direction: $($Plan.Direction)
AD workflow status: $($Context.State.Status)
Move attempted: $($Context.State.MoveAttempted)
Move verified: $($Context.State.MoveVerified)
Observed location: $observed
Operator: $($Context.State.Operator)
Evidence: $($Context.Directory)
Password, application access, home drive, notifications and admin access cleanup: NOT VERIFIED.
Do not close the ticket as fully complete until the manual checks are recorded.
Error: $($Context.State.Error)
"@ | Set-Content (Join-Path $Context.Directory 'ChangeSummary.txt') -Encoding UTF8
    Write-ADMigrationJson $Context.State $Context.StatePath
    $hashes=@(Get-ChildItem $Context.Directory -File | Where-Object Name -ne 'ExecutionEvidenceHashes.json' | ForEach-Object { [pscustomobject]@{File=$_.Name;SHA256=(Get-ADMigrationHash $_.FullName)} })
    Write-ADMigrationJson $hashes (Join-Path $Context.Directory 'ExecutionEvidenceHashes.json')
}
function Invoke-ADMigrationExecution {
    [CmdletBinding(SupportsShouldProcess=$true,ConfirmImpact='High')]
    param($InputData,[guid]$ExpectedUserGUID,[string]$PlanPath,[string]$OutputRoot,[switch]$Resume)
    $plan=Read-ADMigrationExecutionJson $PlanPath
    Assert-ADMigrationPlanIntegrity $plan $InputData $ExpectedUserGUID -AllowPreviousResume:$Resume
    if (-not $Resume) {
        $age=[datetime]::UtcNow-([datetime]$plan.CreatedUtc).ToUniversalTime()
        if ($age.TotalHours -gt 24 -or $age.TotalMinutes -lt -5) { throw 'Preview expired or has a future timestamp. Generate a fresh preview.' }
    }
    $plan.Actions | Format-Table Name,Action,RemoveBeforeMove,RemoveAfterAdd -AutoSize | Out-Host
    if (-not $PSCmdlet.ShouldProcess(($plan.Sam+' / '+$plan.GUID), 'Perform the displayed cross-domain move and exact group actions; no automatic rollback')) { return }
    if ((Read-Host ('Type MIGRATE '+$plan.Sam+' to continue')) -cne ('MIGRATE '+$plan.Sam)) { throw 'Typed confirmation not supplied. No changes.' }
    $ConfirmPreference='None' # Explicit plan and typed confirmation already collected; suppress incidental file-export prompts.
    Assert-ADMigrationSecurityPreflight -ForestRoot $InputData.Config.ForestRoot
    $domains=@(Get-ADMigrationExecutionDomains $plan $InputData.Config.ForestRoot)
    $mutex=New-Object Threading.Mutex($false,('Global\ADMigrationMigration-'+$ExpectedUserGUID.ToString()))
    $cleanupMutex=New-Object Threading.Mutex($false,('Global\ADMigrationActiveSync-'+$ExpectedUserGUID.ToString()))
    $held=$false;$cleanupHeld=$false;$context=$null;$registryStream=$null
    try {
        try { $held=$mutex.WaitOne(0) } catch [Threading.AbandonedMutexException] {$held=$true}
        try { $cleanupHeld=$cleanupMutex.WaitOne(0) } catch [Threading.AbandonedMutexException] {$cleanupHeld=$true}
        if (-not $held -or -not $cleanupHeld) { throw 'Another migration or cleanup process holds this user lock.' }
        $registry=Join-Path $OutputRoot 'ExecutionRegistry';[void][IO.Directory]::CreateDirectory($registry);Protect-ADMigrationDirectory $registry
        $registryPath=Join-Path $registry ($plan.GUID+'.json')
        if ($Resume) {
            $record=Read-ADMigrationExecutionJson $registryPath
            if ($record.PlanHash -ne (Get-ADMigrationHash $PlanPath)) { throw 'Resume requires the exact original execution plan.' }
            $state=Read-ADMigrationExecutionJson $record.StatePath
            if ($state.Version -notin @('1.0.13')) {throw 'Unsupported execution-state version for recovery.'}
            if ($state.PlanHash -ne $record.PlanHash -or $state.GUID -ne $plan.GUID -or -not $state.MoveAttempted) { throw 'Pre-move recovery requires manual review/restoration of journaled removals. No automated retry.' }
            if ($state.Status -eq 'ADVerifiedManualChecksPending') { throw 'AD workflow already verified. Do not repeat it.' }
            $context=[pscustomobject]@{Directory=(Split-Path $record.StatePath -Parent);StatePath=$record.StatePath;State=$state}
            $archive=Join-Path $context.Directory ('ResumeHistory/'+[datetime]::UtcNow.ToString('yyyyMMddTHHmmssfffZ'))
            [void][IO.Directory]::CreateDirectory($archive)
            Get-ChildItem -LiteralPath $context.Directory -File | Copy-Item -Destination $archive
            $state.Operator=[Security.Principal.WindowsIdentity]::GetCurrent().Name
            $state.Error='';$state.Status='ResumingPostMove'
            # Resume NEVER calls Move-ADObject; location must already be conclusively target-only.
            $src=@($domains | Where-Object DNSRoot -eq $plan.SourceDomain)[0];$dst=@($domains | Where-Object DNSRoot -eq $plan.TargetDomain)[0]
            if (@(Find-ADMigrationExecutionUser $ExpectedUserGUID $src).Count -ne 0 -or @(Find-ADMigrationExecutionUser $ExpectedUserGUID $dst).Count -ne 1) { throw 'Resume requires target-only GUID visibility. Investigate source-only, duplicate or unknown outcomes manually.' }
        } else {
            if (Test-Path $registryPath) { throw 'Prior execution record exists. Do not restart. Review recovery state; use Resume only after a verified target-only move.' }
            # Fresh complete audit after confirmation, before any mutation.
            $fresh=New-UserMigrationExecutionPreview $InputData $ExpectedUserGUID $OutputRoot
            $now=Read-ADMigrationExecutionJson $fresh.PlanPath
            foreach ($key in @('GUID','SourceDN','SourceSID','SourceUSN','SourceRID','TargetRID','TargetOU','UPN')) { if ($now.$key -ne $plan.$key) { throw "Fresh audit differs from reviewed plan: $key. Review the new preview." } }
            if (($now.Actions | ConvertTo-Json -Depth 12 -Compress) -ne ($plan.Actions | ConvertTo-Json -Depth 12 -Compress)) { throw 'Fresh actions differ from approved preview.' }
            $directory=Join-Path $OutputRoot ('Execution-'+[datetime]::UtcNow.ToString('yyyyMMddTHHmmssfffZ')+'-'+[guid]::NewGuid().ToString('N').Substring(0,8))
            [void][IO.Directory]::CreateDirectory($directory);Protect-ADMigrationDirectory $directory
            Copy-Item -LiteralPath $plan.AuditDirectory -Destination (Join-Path $directory 'BeforeAudit') -Recurse
            Copy-Item -LiteralPath $now.AuditDirectory -Destination (Join-Path $directory 'FreshAudit') -Recurse
            Copy-Item -LiteralPath $PlanPath -Destination (Join-Path $directory 'ApprovedExecutionPlan.json')
            $state=[pscustomobject]@{Version='1.0.13';GUID=$plan.GUID;PlanHash=(Get-ADMigrationHash $PlanPath);Status='Executing';MoveAttempted=$false;MoveVerified=$false;StartedUtc=[datetime]::UtcNow.ToString('o');UpdatedUtc=[datetime]::UtcNow.ToString('o');Operator=[Security.Principal.WindowsIdentity]::GetCurrent().Name;LastStep='Initialize';Error=''}
            $context=[pscustomobject]@{Directory=$directory;StatePath=(Join-Path $directory 'ExecutionState.json');State=$state}
            Write-ADMigrationJson $state $context.StatePath
            # Persistent exclusive create prevents a second execution with this OutputRoot, even after a crash.
            $registryStream=[IO.File]::Open($registryPath,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
            $record=[pscustomobject]@{PlanHash=$state.PlanHash;StatePath=[IO.Path]::GetFullPath($context.StatePath)}
            $bytes=[Text.Encoding]::UTF8.GetBytes(($record | ConvertTo-Json));$registryStream.Write($bytes,0,$bytes.Length);$registryStream.Flush();$registryStream.Dispose();$registryStream=$null
        }
        Write-ADMigrationExecutionEvent $context 'Execution' 'Started' ('Resume='+[bool]$Resume)
        Invoke-ADMigrationMoveSteps $context $plan $domains -Resume:$Resume
    } catch {
        if ($null -ne $context) { $context.State.Status='StoppedReviewRequired';$context.State.Error=$_.Exception.Message;Write-ADMigrationExecutionEvent $context 'Execution' 'Stopped' $_.Exception.Message }
        throw
    } finally {
        if ($registryStream) {$registryStream.Dispose()}
        try { if ($null -ne $context) { Export-ADMigrationExecutionReport $context $plan $domains;Write-Host ('Execution evidence: '+$context.Directory) } }
        finally { if ($held) {$mutex.ReleaseMutex()};if ($cleanupHeld) {$cleanupMutex.ReleaseMutex()};$mutex.Dispose();$cleanupMutex.Dispose() }
    }
    [pscustomobject]@{Status=$context.State.Status;Directory=$context.Directory}
}
