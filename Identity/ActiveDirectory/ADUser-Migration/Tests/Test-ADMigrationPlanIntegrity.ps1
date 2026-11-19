#Requires -Version 5.1
<#
.SYNOPSIS
    Reproduces Windows PowerShell 5.1 non-enumerated JSON array output.
.NOTES
    Author: Joel Cottrell | Version 1.0.13
    No AD calls. Uses fictional plan and two local evidence files.
#>
[CmdletBinding()]param()
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$m=@(Import-Module (Join-Path $root 'Modules/ADMigration.ADUserMigration.psm1') -Force -PassThru)[0]
$temp=Join-Path ([IO.Path]::GetTempPath()) ('ADMigrationPlanTest-'+[guid]::NewGuid())
[void][IO.Directory]::CreateDirectory($temp)
try { & $m {param($temp)
    $guid=[guid]'11111111-2222-3333-4444-555555555555'
    $group=[pscustomobject]@{Name='Domain Users';SID='S-1-5-21-111-222-333-513';ObjectGUID='aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee';Domain='source.example.test';DistinguishedName='CN=Domain Users,DC=source,DC=example,DC=test';Scope='Global';Category='Security';IsPrimary=$true}
    $mapping=[pscustomobject]@{SourceSID=$group.SID;Status='PrimaryGroupReview';TargetDN='';Approval=''}
    $script:TestApproval=[pscustomobject]@{GroupSIDs=@($group.SID);Mappings=@();Omit=@();RemoveAfterAdd=@()}
    function script:Read-ADMigrationExecutionJson {
        param([string]$Path)
        $v=Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json
        if ([IO.Path]::GetFileName($Path) -eq 'EvidenceHashes.json') {return ,@($v)}
        $v
    }
    $summary=[pscustomobject]@{ObjectGUID=@($guid.ToString());DistinguishedName=@('CN=Fixture,DC=source,DC=example,DC=test');SID=@('S-1-5-21-111-222-333-9999');uSNChanged=@('123');UserPrincipalName=@('fixture@example.test')}
    Write-ADMigrationJson $summary (Join-Path $temp 'UserSummary.json')
    Write-ADMigrationJson ([pscustomobject]@{Groups=@($group);GroupMappings=@($mapping)}) (Join-Path $temp 'PreMigration.json')
    $manifest=@(foreach($name in @('UserSummary.json','PreMigration.json')) {[pscustomobject]@{FileName=$name;SHA256=(Get-ADMigrationHash (Join-Path $temp $name))}})
    Write-ADMigrationJson $manifest (Join-Path $temp 'EvidenceHashes.json')
    $data=[pscustomobject]@{Row=[pscustomobject]@{SamAccountName='Fixture';ChangeReference='TEST-1';MigrationDirection='TEST';TargetOU='OU=Users,DC=target,DC=example,DC=test'};Direction=[pscustomobject]@{SourceDomain='source.example.test';TargetDomain='target.example.test'};CsvHash='a';ConfigHash='b';MapHash='c'}
    $actions=@(New-UserMigrationActionPlan @($group) @($mapping) $script:TestApproval ([pscustomobject]@{DomainSID=[pscustomobject]@{Value='S-1-5-21-444-555-666'}}))
    $plan=[pscustomobject]@{Version='1.0.13';GUID=$guid.ToString();Sam='Fixture';Ticket='TEST-1';Direction='TEST';TargetOU=$data.Row.TargetOU;SourceDomain=$data.Direction.SourceDomain;TargetDomain=$data.Direction.TargetDomain;CsvHash='a';ConfigHash='b';MapHash='c';AuditDirectory=$temp;AuditManifestHash=(Get-ADMigrationHash (Join-Path $temp 'EvidenceHashes.json'));SourceDN=$summary.DistinguishedName[0];SourceSID=$summary.SID[0];SourceUSN='123';UPN=$summary.UserPrincipalName[0];InvariantAttributes=[pscustomobject]@{};Actions=$actions}
    Assert-ADMigrationPlanIntegrity $plan $data $guid
    Write-Host 'PASS: Non-enumerated JSON manifest validates every file using scalar child paths'
    $plan.Version='1.0.9'
    $threw=$false;try{Assert-ADMigrationPlanIntegrity $plan $data $guid -AllowPreviousResume}catch{$threw=$true}
    if(-not $threw){throw 'Unsupported old plan accepted for resume'}
    Write-Host 'PASS: Unsupported plan version rejected even for resume'
    $plan.Version='1.0.13'
    Add-Content (Join-Path $temp 'UserSummary.json') 'tampered'
    $threw=$false;try{Assert-ADMigrationPlanIntegrity $plan $data $guid}catch{$threw=$true}
    if(-not $threw){throw 'Tampered evidence was accepted'}
    Write-Host 'PASS: Manifest enumeration fix still rejects modified evidence'
} $temp } finally {Remove-Module $m -Force;Remove-Item $temp -Recurse -Force}
