#Requires -Version 5.1
<#
.SYNOPSIS
    Offline parser, safety and decision tests. Does not contact AD.
.NOTES
    Author: Joel Cottrell | Version 1.0.13 | 2026-10-22
#>
[CmdletBinding()]
param([switch]$Portable)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$count=0
function Assert-ADMigration { param([bool]$Condition,[string]$Message) if (-not $Condition) { throw "FAIL: $Message" }; $script:count++; Write-Host "PASS: $Message" }
function Assert-ADMigrationThrows { param([scriptblock]$Action,[string]$Message) $threw=$false; try { & $Action } catch { $threw=$true }; Assert-ADMigration $threw $Message }
foreach ($file in Get-ChildItem -LiteralPath $root -Recurse -File | Where-Object Extension -in '.ps1','.psm1') {
    $tokens=$null; $errors=$null
    $ast=[Management.Automation.Language.Parser]::ParseFile($file.FullName,[ref]$tokens,[ref]$errors)
    Assert-ADMigration ($errors.Count -eq 0) ('Parser: '+$file.Name+' '+(@($errors | ForEach-Object Message) -join '; '))
    if ($file.Directory.Name -ne 'Tests') {
        $commands=@($ast.FindAll({ param($node) $node -is [Management.Automation.Language.CommandAst] },$true))
        foreach ($command in @($commands | Where-Object { $_.GetCommandName() -eq 'Get-Content' -and $_.Extent.Text -match '-Raw' })) {
            Assert-ADMigration ($command.Extent.Text -match '-Encoding UTF8') ('Explicit UTF8 JSON read: '+$file.Name)
        }
        $bad=@($commands | Where-Object { $_.GetCommandName() -match '^(Move|Set|Add|Remove|New|Enable|Disable|Restore|Rename|Clear|Unlock|Reset)-AD' })
        if ($file.Name -eq 'ADMigration.Execution.ps1') {
            Assert-ADMigration ($bad.Count -eq 5 -and @($bad | Where-Object { $_.GetCommandName() -notin @('Move-ADObject','Add-ADGroupMember','Remove-ADGroupMember','Set-ADGroup') }).Count -eq 0) 'Execution module contains only move and individual group membership changes'
            foreach ($write in @($bad | Where-Object { $_.GetCommandName() -eq 'Set-ADGroup' })) {
                Assert-ADMigration ($write.Extent.Text -match '-(Add|Remove) @\{member=' -and $write.Extent.Text -notmatch '-(Replace|Clear|GroupCategory|GroupScope)') 'Distribution writes change only one member link'
            }
        } elseif ($file.Name -eq 'ADMigration.ActiveSyncCleanup.ps1') {
            Assert-ADMigration ($bad.Count -eq 1 -and $bad[0].GetCommandName() -eq 'Remove-ADObject' -and $bad[0].Extent.Text -notmatch '-Recursive') 'Only individual AD child deletion exists in cleanup module'
        } else { Assert-ADMigration ($bad.Count -eq 0) ('No AD mutation commands: '+$file.Name) }
        Assert-ADMigration (@($commands | Where-Object { $_.GetCommandName() -in @('Invoke-Expression','Invoke-Command') }).Count -eq 0) ('No expression or remoting execution: '+$file.Name)
        foreach ($command in @($commands | Where-Object { $_.GetCommandName() -eq 'Start-Process' })) {
            $owner=$command.Parent
            while ($null -ne $owner -and $owner -isnot [Management.Automation.Language.FunctionDefinitionAst]) { $owner=$owner.Parent }
            Assert-ADMigration ($null -ne $owner -and $owner.Name -eq 'Start-ADMigrationElevatedAudit') 'Process launch restricted to UAC helper'
            Assert-ADMigration ($command.Extent.Text -match '-Verb RunAs') 'Process launch requires normal UAC elevation'
        }
    }
}
$modulePath=(Resolve-Path -LiteralPath (Join-Path $root 'Modules\ADMigration.ADUserMigration.psm1')).ProviderPath
$importedModules=@(Import-Module $modulePath -Force -PassThru)
Assert-ADMigration ($importedModules.Count -eq 1) 'Exactly one module returned by this import'
$module=$importedModules[0]
Assert-ADMigration ($module.Path -eq $modulePath) 'Tests bound to the module in this package folder'
Assert-ADMigration ((ConvertTo-ADMigrationLdapValue 'a*(b)\c') -eq 'a\2a\28b\29\5cc') 'LDAP filter metacharacters escaped'
Assert-ADMigration ((ConvertTo-ADMigrationLdapValue ('x'+[char]0+'y')) -eq 'x\00y') 'LDAP NUL escaped'
$temp=Join-Path ([IO.Path]::GetTempPath()) ('ADMigration-OfflineTests-'+[guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($temp)
try {
    $csv=Join-Path $temp 'pilot.csv'; $cfg=Join-Path $temp 'config.json'; $map=Join-Path $temp 'map.csv'
    Copy-Item (Join-Path $root 'Config\MigrationConfig.example.json') $cfg
    Copy-Item (Join-Path $root 'Config\GroupMappings.example.csv') $map
    $row=[pscustomobject]@{SamAccountName='fixture.user';MigrationDirection='ROOT_TO_CHILD';TargetOU='';ChangeReference='CHANGE-101'}
    $row | Export-Csv $csv -NoTypeInformation
    $data=Read-ADMigrationInput $csv $cfg $map
    Assert-ADMigration ($data.Row.TargetOU -eq 'OU=ExampleUsers,DC=branch,DC=example,DC=test') 'Forward default OU'
    $row.MigrationDirection='CHILD_TO_ROOT'; $row | Export-Csv $csv -NoTypeInformation
    $reverse=Read-ADMigrationInput $csv $cfg $map
    Assert-ADMigration ($reverse.Direction.SourceDomain -eq 'branch.example.test') 'Reverse direction source'
    Assert-ADMigration ($reverse.Row.TargetOU -like 'OU=ExampleUsers,*') 'Reverse default OU'
    $checkedConfig=Get-Content -LiteralPath $cfg -Raw -Encoding UTF8 | ConvertFrom-Json
    $checkedConfig.ChildDomain='unrelated.test'
    $checkedConfig | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $cfg -Encoding UTF8
    Assert-ADMigrationThrows { Read-ADMigrationInput $csv $cfg $map } 'Different forest rejected offline'
    $checkedConfig.ChildDomain='branch.example.test'
    $checkedConfig.Directions.ROOT_TO_CHILD.TargetDomain='other.example.test'
    $checkedConfig | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $cfg -Encoding UTF8
    Assert-ADMigrationThrows { Read-ADMigrationInput $csv $cfg $map } 'Mismatched direction pair rejected offline'
    Copy-Item (Join-Path $root 'Config/MigrationConfig.example.json') $cfg -Force
    $row.TargetOU='OU=ExampleUsers,DC=branch,DC=example,DC=test'; $row | Export-Csv $csv -NoTypeInformation
    Assert-ADMigrationThrows { Read-ADMigrationInput $csv $cfg $map } 'Child OU rejected when the target is the root domain'
    $row.TargetOU=''; $row | Export-Csv $csv -NoTypeInformation
    & $module {
        function script:Get-ADForest {
            param($Server,$ErrorAction)
            if ($Server -ne 'example.test') { throw 'Test received an unexpected forest root.' }
            [pscustomobject]@{RootDomain='unrelated.test';Domains=@('unrelated.test')}
        }
        function script:Get-ADDomain { throw 'Domain discovery must not run after a forest mismatch.' }
    }
    $forestError = try { & $module { Get-ADMigrationExecutionDomains @{} 'example.test' } } catch { $_.Exception.Message }
    Assert-ADMigration ($forestError -eq 'Unexpected forest root.') 'Execution discovery rejects the wrong forest before enumerating domains'
    & $module { Remove-Item Function:/Get-ADForest,Function:/Get-ADDomain }
    @($row,$row) | Export-Csv $csv -NoTypeInformation
    Assert-ADMigrationThrows { Read-ADMigrationInput $csv $cfg $map } 'Multiple pilots rejected'
    $row.MigrationDirection='INVALID'; $row | Export-Csv $csv -NoTypeInformation
    Assert-ADMigrationThrows { Read-ADMigrationInput $csv $cfg $map } 'Invalid direction rejected'
    $row.MigrationDirection='ROOT_TO_CHILD'; $row.SamAccountName='REPLACE_WITH_PILOT'; $row | Export-Csv $csv -NoTypeInformation
    Assert-ADMigrationThrows { Read-ADMigrationInput $csv $cfg $map } 'Placeholder rejected'
    $row.SamAccountName='fixture.user'; $row.ChangeReference=''; $row | Export-Csv $csv -NoTypeInformation
    Assert-ADMigrationThrows { Read-ADMigrationInput $csv $cfg $map } 'Missing change reference rejected'
    $row.ChangeReference='CHANGE-101'; $row | Export-Csv $csv -NoTypeInformation
    $mapping=[pscustomobject]@{MigrationDirection='ROOT_TO_CHILD';SourceGroupSID='S-1-5-21-1-2-3-1000';TargetGroupSID='';Action='Retain';ApprovedBy='Reviewer';ApprovalReference='CHANGE-101'}
    @($mapping,$mapping) | Export-Csv $map -NoTypeInformation
    Assert-ADMigrationThrows { Read-ADMigrationInput $csv $cfg $map } 'Duplicate map rejected'
    $mapping.ApprovedBy=''; $mapping | Export-Csv $map -NoTypeInformation
    Assert-ADMigrationThrows { Read-ADMigrationInput $csv $cfg $map } 'Unapproved map rejected'
    & $module {
        # Module-local mock: no AD module required or contacted.
        function script:Get-ADGroup { param($Identity,$Server,$LDAPFilter,$SearchBase) [pscustomobject]@{DistinguishedName='CN=Same,DC=branch,DC=example,DC=test';GroupCategory='Security'} }
    }
    $ctx=[pscustomobject]@{Findings=(New-Object 'System.Collections.Generic.List[object]');LogPath=(Join-Path $temp 'test.jsonl')}
    $group=[pscustomobject]@{Name='ExampleApp-PRD';SID='S-1-5-21-1-2-3-1000';DistinguishedName='CN=ExampleApp-PRD,DC=example,DC=test';Domain='example.test';Scope='Global';Category='Security';IsPrimary=$false}
    $target=[pscustomobject]@{RIDMaster='mock';DNSRoot='branch.example.test';DistinguishedName='DC=branch,DC=example,DC=test';DomainSID=[pscustomobject]@{Value='S-1-5-21-4-5-6'}}
    $analysis=@(Get-ADMigrationMappingAnalysis @($group) $data $target $ctx)
    Assert-ADMigration ($analysis[0].Status -eq 'ExactNameCandidate') 'Exact names never imply approval'
    $mapping.ApprovedBy='Reviewer'; $data.Maps=@($mapping)
    $analysis=@(Get-ADMigrationMappingAnalysis @($group) $data $target $ctx)
    Assert-ADMigration ($analysis[0].Status -eq 'ScopeConflict') 'Source global group cannot be retained across domain'
    $mapping.Action='Map'; $mapping.TargetGroupSID='S-1-5-21-4-5-6-1000'
    $analysis=@(Get-ADMigrationMappingAnalysis @($group) $data $target $ctx)
    Assert-ADMigration ($analysis[0].Status -eq 'ConfiguredMapping') 'Configured SID mapping resolves'
    $group.IsPrimary=$true
    $analysis=@(Get-ADMigrationMappingAnalysis @($group) $data $target $ctx)
    Assert-ADMigration ($analysis[0].Status -eq 'PrimaryGroupReview') 'Primary membership cannot be silently mapped'
    $state=Join-Path $temp 'state.json'
    & $module { param($path) Write-ADMigrationJson @{Status='Running'} $path; Write-ADMigrationJson @{Status='Blocked'} $path } $state
    Assert-ADMigration ((Get-Content $state -Raw -Encoding UTF8 | ConvertFrom-Json).Status -eq 'Blocked') 'Atomic state replacement'
    & $module { param($path) Write-ADMigrationJson @{Status='ReviewRequired';Message='State replacement regression'} $path } $state
    Assert-ADMigration ((Get-Content $state -Raw -Encoding UTF8 | ConvertFrom-Json).Status -eq 'ReviewRequired') 'Repeated state replacement'
    Assert-ADMigration (@(Get-ChildItem -LiteralPath $temp -Filter 'state.json.*.bak').Count -eq 0) 'Successful replacement removes backup'
    Assert-ADMigration (@(Get-ChildItem -LiteralPath $temp -Filter 'state.json.*.tmp').Count -eq 0) 'Successful replacement consumes temporary file'
    Assert-ADMigrationThrows { Invoke-ADMigrationAudit -InputData $data -OutputRoot (Join-Path $temp 'out') -ResumeState $state } 'Invalid resume state rejected'
    if (-not $Portable) {
    # Snapshot regression fixtures contain binary, SID, dates and multivalued data.
    $snapshotPath=Join-Path $temp 'snapshot.clixml'
    $fixture=[pscustomobject]@{
        Name='Pilot'; Binary=[byte[]](0,1,127,255); Tags=@('one','two'); Empty=@()
        Identifier=[guid]'00000000-0000-0000-0000-000000000001'
        SID=(New-Object Security.Principal.SecurityIdentifier('S-1-5-21-1-2-3-1001'))
        Timestamp=[datetime]'2026-10-22T12:00:00Z'; Large=[int64]::MaxValue
    }
    & $module { param($object,$path) Export-ADMigrationSnapshot -Objects @($object) -Path $path } $fixture $snapshotPath
    $snapshot=Import-Clixml -LiteralPath $snapshotPath
    $attributes=$snapshot.Items[0].Attributes
    Assert-ADMigration ($attributes.Binary.Base64 -eq 'AAF//w==') 'Snapshot binary preserved as Base64'
    Assert-ADMigration ($attributes.Tags.Count -eq 2 -and $attributes.Tags[1] -eq 'two') 'Snapshot multivalue preserved'
    Assert-ADMigration ($attributes.Empty.Count -eq 0) 'Snapshot empty collection preserved'
    Assert-ADMigration ($attributes.SID.Value -eq 'S-1-5-21-1-2-3-1001') 'Snapshot SID preserved'
    Assert-ADMigration ($attributes.Large.Value -eq '9223372036854775807') 'Snapshot Int64 precision preserved'
    Assert-ADMigration ($attributes.Identifier.Value -eq '00000000-0000-0000-0000-000000000001') 'Snapshot GUID preserved'
    $json=Get-Content -LiteralPath ([IO.Path]::ChangeExtension($snapshotPath,'.json')) -Raw -Encoding UTF8 | ConvertFrom-Json
    Assert-ADMigration ($json.Items[0].Attributes.Binary.Base64 -eq $attributes.Binary.Base64) 'JSON and CLIXML binary agree'
    Assert-ADMigrationThrows { & $module { ConvertTo-ADMigrationAttributeValue -Value (New-Object object) } } 'Unsupported snapshot type fails explicitly'
    }
    # v1.0.13 regression cases: retain identity before searching names.
    $data.Maps=@(); $group.IsPrimary=$false; $group.Scope='Universal'
    $analysis=@(Get-ADMigrationMappingAnalysis @($group) $data $target $ctx)
    Assert-ADMigration ($analysis[0].Status -eq 'SameGroupRetentionReview' -and $analysis[0].TargetSID -eq $group.SID) 'Shared universal group keeps original identity for retention review'
    $group.Scope='DomainLocal'
    $analysis=@(Get-ADMigrationMappingAnalysis @($group) $data $target $ctx)
    Assert-ADMigration ($analysis[0].Status -eq 'SameGroupRetentionReview') 'Domain-local group is not forced into replacement matching'
    $group.Scope='Global';$group.Domain=$target.DNSRoot
    $analysis=@(Get-ADMigrationMappingAnalysis @($group) $data $target $ctx)
    Assert-ADMigration ($analysis[0].Status -eq 'SameGroupRetentionReview') 'Target-domain global group is eligible for retention review'
    $group.Domain='example.test'
    $analysis=@(Get-ADMigrationMappingAnalysis @($group) $data $target $ctx)
    Assert-ADMigration ($analysis[0].Status -eq 'ExactNameCandidate') 'Source global group still requires replacement disposition'
    $observations=& $module {
        $id=[guid]'00000000-0000-0000-0000-000000000001'
        Get-ADMigrationUSNObservation ([int64]6410435384) 'dc.example.org' $id 'Initial'
        Get-ADMigrationUSNObservation @('6410435384') 'dc.example.org' $id 'Final'
    }
    $comparison=& $module {param($o) Compare-ADMigrationUSNObservations $o} $observations
    Assert-ADMigration ($comparison.Status -eq 'Unchanged') 'Int64 above 32-bit and singleton string compare equally'
    $observations[1].CanonicalValue='6410435385'
    $comparison=& $module {param($o) Compare-ADMigrationUSNObservations $o} $observations
    Assert-ADMigration ($comparison.Status -eq 'Changed') 'Real USN difference remains blocking'
    $observations[1].Server='other.example.org'
    $comparison=& $module {param($o) Compare-ADMigrationUSNObservations $o} $observations
    Assert-ADMigration ($comparison.Status -eq 'Invalid') 'Different DC observations cannot pass consistency'
    foreach ($value in @($null,'invalid','9223372036854775808',@('1','2'))) {
        $o=& $module {param($v) Get-ADMigrationUSNObservation -Value $v -Server 'dc' -ObjectGUID ([guid]::Empty) -Label 'Invalid'} $value
        Assert-ADMigration (-not $o.Valid) 'Missing, malformed, overflow or multivalued USN fails closed'
    }
    $children=@(
        [pscustomobject]@{GUID='1';DN='CN=Devices,CN=User';Class='msExchActiveSyncDevices'},
        [pscustomobject]@{GUID='2';DN='CN=Phone,CN=Devices,CN=User';Class='msExchActiveSyncDevice'},
        [pscustomobject]@{GUID='3';DN='CN=Other,CN=Devices,CN=User';Class='container'})
    $cleanup=@(& $module {param($c) Get-ADMigrationChildCleanupPlan $c} $children)
    Assert-ADMigration (@($cleanup | Where-Object RequiredBeforeMove).Count -eq 2) 'Both ActiveSync container and device require cleanup'
    Assert-ADMigration ($cleanup[2].Disposition -eq 'UnknownClassReviewBlocksCleanup') 'Unknown descendant is never implicitly approved'
    Assert-ADMigration (@($cleanup | Where-Object ExecutionAvailable).Count -eq 0) 'Cleanup plan has no execution mode'
    $keys=& $module { Get-ADMigrationMatchKey 'FictionalSuite_Users_Portal_Branch' -TrailingSuffix 'Branch'; Get-ADMigrationMatchKey 'FictionalSuite Users Portal'; Get-ADMigrationMatchKey 'FictionalSuite Users Train Portal' }
    Assert-ADMigration ($keys[0] -eq $keys[1] -and $keys[1] -ne $keys[2]) 'Normalization recognizes Branch suffix while preserving Train'
    $fakeGroups=@(
        [pscustomobject]@{Name='ExampleApp PRD';SamAccountName='ExampleAppPRD';DisplayName='';SID='1';Domain='example.test';Scope='Universal';Category='Security';IsSeed=$true;ParentSIDs=@('9')},
        [pscustomobject]@{Name='ExampleApp_PRD_Branch';SamAccountName='ExampleAppPRDBranch';DisplayName='';SID='2';Domain='example.test';Scope='Universal';Category='Security';IsSeed=$true;ParentSIDs=@('9')},
        [pscustomobject]@{Name='ExampleApp-PRD';SamAccountName='ExampleAppPRD';DisplayName='';SID='3';Domain='branch.example.test';Scope='Global';Category='Security';IsSeed=$true;ParentSIDs=@('9')})
    $pairs=@(& $module {param($g) Get-ADMigrationCatalogCandidates $g -TrailingSuffix Branch} $fakeGroups)
    Assert-ADMigration ($pairs.Count -eq 3 -and @($pairs | Where-Object Status -eq 'AmbiguousMatch').Count -eq 3) 'Ambiguous same-domain and cross-domain alternatives are retained'
    Assert-ADMigration (@($pairs | Where-Object Approved).Count -eq 0) 'Shared parent never approves an equivalent'
    Assert-ADMigrationThrows { & $module {param($g) Get-ADMigrationCatalogCandidates $g -MaxPairs 1 -TrailingSuffix Branch} $fakeGroups } 'Candidate cap reports incomplete instead of silently truncating'
    $catalogDir=Join-Path $temp 'catalog';[void][IO.Directory]::CreateDirectory($catalogDir)
    $catalogContext=[pscustomobject]@{Directory=$catalogDir;Findings=(New-Object 'System.Collections.Generic.List[object]');LogPath=(Join-Path $catalogDir 'test.jsonl')}
    & $module {
        $script:CatalogQueryCount=0
        function script:Get-ADGroup {
            param($Filter,$SearchBase,$Server,$Properties,$ResultPageSize,$ErrorAction)
            $script:CatalogQueryCount++
            if ($Server -eq 'parent') {
                [pscustomobject]@{Name='FictionalSuite App';SamAccountName='FictionalSuiteApp';DisplayName='';SID=[pscustomobject]@{Value='S-1-5-21-1-2-3-1'};ObjectGUID=[guid]'00000000-0000-0000-0000-000000000001';DistinguishedName='CN=App,DC=example,DC=test';GroupScope='Universal';GroupCategory='Security';Description='';ManagedBy='';member=@('CN=Bridge,DC=example,DC=test')}
                [pscustomobject]@{Name='Bridge';SamAccountName='Bridge';DisplayName='';SID=[pscustomobject]@{Value='S-1-5-21-1-2-3-2'};ObjectGUID=[guid]'00000000-0000-0000-0000-000000000002';DistinguishedName='CN=Bridge,DC=example,DC=test';GroupScope='Universal';GroupCategory='Security';Description='';ManagedBy='';member=@('CN=App,DC=example,DC=test','CN=App,DC=branch,DC=example,DC=test')}
            } else {
                [pscustomobject]@{Name='FictionalSuite_App_Branch';SamAccountName='FictionalSuiteAppBranch';DisplayName='';SID=[pscustomobject]@{Value='S-1-5-21-4-5-6-1'};ObjectGUID=[guid]'00000000-0000-0000-0000-000000000003';DistinguishedName='CN=App,DC=branch,DC=example,DC=test';GroupScope='Universal';GroupCategory='Security';Description='';ManagedBy='';member=@()}
            }
        }
        function script:Get-ADObject {param($LDAPFilter,$SearchBase,$Server,$Properties,$ErrorAction)}
    }
    $mockDomains=@([pscustomobject]@{DNSRoot='example.test';RIDMaster='parent';DistinguishedName='DC=example,DC=test'},[pscustomobject]@{DNSRoot='branch.example.test';RIDMaster='child';DistinguishedName='DC=branch,DC=example,DC=test'})
    & $module {param($d,$c,$cfg) Invoke-ADMigrationGroupCatalog -Domains $d -DirectGroups @() -Context $c -Config $cfg} $mockDomains $catalogContext $data.Config
    $catalogSummary=Get-Content (Join-Path $catalogDir 'GroupCatalogSummary.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    Assert-ADMigration ($catalogSummary.SelectedCount -eq 3 -and $catalogSummary.NestingEdges -eq 3) 'Catalog follows nesting beyond prefixes and terminates on a cycle'
    Assert-ADMigration ((& $module {$script:CatalogQueryCount}) -eq 2) 'Catalog reads each domain once'
    Assert-ADMigration (@(Import-Csv (Join-Path $catalogDir 'GroupMatchCandidates.csv')).Count -eq 1) 'Catalog emits one deduplicated name candidate'
    $emptyCSV=Join-Path $temp 'empty.csv'
    & $module {param($p) Export-ADMigrationCsv -Rows @() -Path $p -Columns @('Name','SID')} $emptyCSV
    Assert-ADMigration ((Get-Content $emptyCSV -TotalCount 1) -eq '"Name","SID"') 'Empty evidence CSV retains column headers'

    if (-not $Portable) {
    # Exercise UAC handoff without opening a process or contacting AD.
    & $module {
        $script:CapturedLaunch=$null
        function script:Protect-ADMigrationDirectory { param($Path) }
        function script:Start-Process {
            param($FilePath,$Verb,$ArgumentList,[switch]$PassThru,$ErrorAction)
            $script:CapturedLaunch=[pscustomobject]@{FilePath=$FilePath;Verb=$Verb;ArgumentList=$ArgumentList}
            [pscustomobject]@{Id=1234}
        }
    }
    $forward=@{CsvPath=$csv;ConfigPath=$cfg;GroupMapPath=$map;OutputRoot=$temp;DryRun=$true;TestMode=$false;Confirm=$false}
    Start-ADMigrationElevatedAudit -PackageRoot $root -Parameters $forward
    $launch=& $module { $script:CapturedLaunch }
    Assert-ADMigration ($launch.Verb -eq 'RunAs') 'Elevation handoff uses RunAs'
    Assert-ADMigration ($launch.ArgumentList -match '-NoProfile -STA -NoExit -File') 'Elevation uses fixed bootstrap file'
    Assert-ADMigration ($launch.ArgumentList -notmatch 'ExecutionPolicy|EncodedCommand') 'Elevation does not bypass policy or encode code'
    $match=[regex]::Match($launch.ArgumentList,'-RequestPath "([^"]+)"')
    Assert-ADMigration ($match.Success) 'Elevation request path quoted'
    $requestPath=$match.Groups[1].Value
    try {
        $request=Get-Content -LiteralPath $requestPath -Raw -Encoding UTF8 | ConvertFrom-Json
        Assert-ADMigration ($request.Parameters.DryRun -eq $true -and $request.Parameters.Confirm -eq $false) 'Elevation preserves switch values including false'
        Assert-ADMigration ($request.Parameters.CsvPath -eq $csv) 'Elevation preserves resolved CSV path'
    } finally {
        [IO.File]::Delete($requestPath)
        [IO.Directory]::Delete([IO.Path]::GetDirectoryName($requestPath))
    }
    }
    Write-Host "All $count offline assertions passed. This is not live AD validation."
} finally {
    Remove-Module -ModuleInfo $module -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $temp -Recurse -Force
}
