#Requires -Version 5.1
<#
.SYNOPSIS
    Read-only AD user migration assessment engine.
.NOTES
    Author: Joel Cottrell
    Version: 1.0.13 | 2026-10-22
    Change History: 1.0.2 - Snapshot, validation, mapping, evidence and resume.
    Audit remains read-only. Separate explicit ActiveSync cleanup entry point is available.
#>
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'ADMigration.AuditSupport.ps1')
. (Join-Path $PSScriptRoot 'ADMigration.ActiveSyncCleanup.ps1')
. (Join-Path $PSScriptRoot 'ADMigration.Execution.ps1')

function Write-ADMigrationSection {
    param([string]$Title)
    $width=76
    $line=([string][char]0x2550) * $width
    Write-Host ''
    Write-Host (([string][char]0x2554)+$line+([string][char]0x2557)) -ForegroundColor Cyan
    Write-Host (([string][char]0x2551)+' '+$Title.PadRight($width-2)+ ' '+([string][char]0x2551)) -ForegroundColor White
    Write-Host (([string][char]0x255A)+$line+([string][char]0x255D)) -ForegroundColor Cyan
}
function Assert-ADMigrationSecurityPreflight {
    param([Parameter(Mandatory)][string]$ForestRoot)
    Write-ADMigrationSection 'ADMINISTRATOR SECURITY PREFLIGHT'
    if (-not (Get-Module -ListAvailable -Name ActiveDirectory)) { throw 'ActiveDirectory module is missing. Install RSAT using your approved process.' }
    Import-Module ActiveDirectory -ErrorAction Stop
    $forest=Get-ADForest -Server $ForestRoot -ErrorAction Stop
    if ($forest.RootDomain -ne $ForestRoot) { throw 'Unexpected forest root.' }
    $domains=@(foreach ($dns in $forest.Domains) { Get-ADDomain -Identity $dns -Server $dns })
    $root=@($domains | Where-Object DNSRoot -eq $forest.RootDomain)
    if ($root.Count -ne 1) { throw 'Cannot resolve forest-root domain.' }
    $operator=Test-ADMigrationOperator -Domains $domains -RootDomain $root[0]
    $operator | Select-Object Name,Enabled,DirectoryEnterpriseAdmin,EnabledTokenEnterpriseAdmin,Elevated,DirectoryProtectedUsers,TokenProtectedUsers | Format-List | Out-Host
    if (-not $operator.Enabled -or -not $operator.DirectoryEnterpriseAdmin -or -not $operator.EnabledTokenEnterpriseAdmin -or -not $operator.Elevated) { throw 'Administrator preflight failed. An enabled Enterprise Admin account and elevated EA token are required. Follow approved elevation procedure and sign out/in after changes.' }
    if ($operator.DirectoryProtectedUsers -or $operator.TokenProtectedUsers) { throw 'Administrator preflight failed: Protected Users membership/token is present. Follow your approved procedure; the tool never changes membership.' }
    Write-Host '[PASS] Administrator security preflight. No AD changes.' -ForegroundColor Green
}
function Test-ADMigrationProcessElevated {
    $identity=[Security.Principal.WindowsIdentity]::GetCurrent()
    try {
        $principal=New-Object Security.Principal.WindowsPrincipal($identity)
        $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    } finally { $identity.Dispose() }
}
function Start-ADMigrationElevatedAudit {
    param([string]$PackageRoot,[hashtable]$Parameters)
    # Only data is transferred. No generated PowerShell code or encoded commands.
    $requestDirectory=Join-Path ([IO.Path]::GetTempPath()) ('ADMigrationElevation-'+[guid]::NewGuid().ToString('N'))
    [void][IO.Directory]::CreateDirectory($requestDirectory)
    Protect-ADMigrationDirectory $requestDirectory
    $requestPath=Join-Path $requestDirectory 'Request.json'
    $identity=[Security.Principal.WindowsIdentity]::GetCurrent()
    try { $sid=$identity.User.Value } finally { $identity.Dispose() }
    foreach ($name in @('CsvPath','ConfigPath','GroupMapPath','OutputRoot','ResumeState')) {
        if ($Parameters.ContainsKey($name) -and $Parameters[$name]) {
            $Parameters[$name]=$ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath([string]$Parameters[$name])
        }
    }
    $request=[ordered]@{SchemaVersion=1;ExpectedSID=$sid;Parameters=$Parameters}
    Write-ADMigrationJson $request $requestPath
    $bootstrap=Join-Path $PackageRoot 'Start-ADMigrationElevatedSession.ps1'
    if ($bootstrap.Contains('"') -or $requestPath.Contains('"')) { throw 'Invalid quotation mark in elevation path.' }
    $arguments='-NoProfile -STA -NoExit -File "{0}" -RequestPath "{1}"' -f $bootstrap,$requestPath
    Write-Host 'Windows will request UAC elevation. Continue in the new PowerShell window.' -ForegroundColor Yellow
    try {
        $process=Start-Process -FilePath (Join-Path $PSHOME 'powershell.exe') -Verb RunAs -ArgumentList $arguments -PassThru -ErrorAction Stop
        Write-Host ('Elevated audit window launched, process '+$process.Id+'. The original window will not run the audit.')
    } catch {
        if ([IO.File]::Exists($requestPath)) { [IO.File]::Delete($requestPath) }
        [IO.Directory]::Delete($requestDirectory)
        throw 'Elevation was cancelled or could not be started. No audit was launched. You can start Windows PowerShell as administrator and retry.'
    }
}
function ConvertTo-ADMigrationAttributeValue {
    param([AllowNull()]$Value,[int]$Depth=0)
    if ($Depth -gt 8) { throw 'Snapshot attribute nesting exceeded 8 levels. Snapshot is incomplete; no values were silently truncated.' }
    if ($null -eq $Value) { return $null }
    if ($Value -is [byte[]]) { return [pscustomobject]@{Kind='Binary';Base64=[Convert]::ToBase64String($Value)} }
    if ($Value -is [Security.Principal.SecurityIdentifier]) { return [pscustomobject]@{Kind='SID';Value=$Value.Value} }
    if ($Value -is [guid]) { return [pscustomobject]@{Kind='Guid';Value=$Value.ToString()} }
    if ($Value -is [datetime]) { return [pscustomobject]@{Kind='DateTime';Value=$Value.ToString('o')} }
    if ($Value -is [timespan]) { return [pscustomobject]@{Kind='TimeSpan';Ticks=$Value.Ticks.ToString()} }
    if ($Value -is [int64] -or $Value -is [uint64]) { return [pscustomobject]@{Kind=$Value.GetType().Name;Value=$Value.ToString([Globalization.CultureInfo]::InvariantCulture)} }
    if ($Value -is [Security.AccessControl.ObjectSecurity]) {
        return [pscustomobject]@{Kind='SecurityDescriptor';Base64=[Convert]::ToBase64String($Value.GetSecurityDescriptorBinaryForm());SDDL=$Value.GetSecurityDescriptorSddlForm([Security.AccessControl.AccessControlSections]::All)}
    }
    if ($Value -is [System.Enum]) { return [pscustomobject]@{Kind=$Value.GetType().FullName;Value=$Value.ToString()} }
    if ($Value -is [string] -or $Value.GetType().IsPrimitive -or $Value -is [decimal]) { return $Value }
    if ($Value -is [Collections.IDictionary]) {
        $result=[ordered]@{}
        foreach ($key in $Value.Keys) { $result[[string]$key]=ConvertTo-ADMigrationAttributeValue -Value $Value[$key] -Depth ($Depth+1) }
        return [pscustomobject]$result
    }
    if ($Value -is [Collections.IEnumerable]) {
        $result=New-Object 'System.Collections.Generic.List[object]'
        foreach ($item in $Value) { $result.Add((ConvertTo-ADMigrationAttributeValue -Value $item -Depth ($Depth+1))) }
        return ,$result.ToArray()
    }
    throw ('Unsupported snapshot attribute type: '+$Value.GetType().FullName+'. Snapshot blocked rather than silently dropping data.')
}
function Export-ADMigrationSnapshot {
    param([AllowEmptyCollection()][object[]]$Objects,[string]$Path)
    $items=New-Object 'System.Collections.Generic.List[object]'
    foreach ($object in $Objects) {
        $attributes=[ordered]@{}
        foreach ($property in $object.PSObject.Properties) {
            try { $attributes[$property.Name]=ConvertTo-ADMigrationAttributeValue -Value $property.Value }
            catch { throw ('Snapshot property '+$property.Name+': '+$_.Exception.Message) }
        }
        $items.Add([pscustomobject]@{SourceType=$object.GetType().FullName;Attributes=[pscustomobject]$attributes})
    }
    $snapshot=[pscustomobject]@{SnapshotSchemaVersion=1;CapturedUtc=[datetime]::UtcNow.ToString('o');Items=$items.ToArray()}
    # Only normalized scalars/collections reach the serializer, never live AD objects.
    Export-Clixml -InputObject $snapshot -LiteralPath $Path -Depth 24 -Encoding UTF8
    Write-ADMigrationJson $snapshot ([IO.Path]::ChangeExtension($Path,'.json'))
}
function Invoke-ADMigrationMeasuredRead {
    param($Context,[string]$Name,[scriptblock]$Action)
    Add-UserMigrationFinding $Context ($Name+'.Start') 'Info' 'Started. If this is the last line, this operation is still running or was interrupted.'
    $timer=[Diagnostics.Stopwatch]::StartNew()
    try {
        & $Action
        Add-UserMigrationFinding $Context ($Name+'.Complete') 'Info' ('Completed in {0:N2} seconds.' -f $timer.Elapsed.TotalSeconds)
    } catch {
        Add-UserMigrationFinding $Context ($Name+'.Failed') 'Blocker' ('Failed after {0:N2} seconds: {1}' -f $timer.Elapsed.TotalSeconds,$_.Exception.Message)
        throw
    } finally { $timer.Stop() }
}

function ConvertTo-ADMigrationLdapValue {
    param([AllowEmptyString()][string]$Value)
    $Value.Replace('\','\5c').Replace('*','\2a').Replace('(','\28').Replace(')','\29').Replace([string][char]0,'\00')
}
function Get-ADMigrationOptionalProperty {
    param($Object,[string]$Name)
    if ($null -ne $Object -and $Object.PSObject.Properties.Name -contains $Name) { $Object.$Name }
}
function Protect-ADMigrationDirectory {
    param([string]$Path)
    $acl = New-Object Security.AccessControl.DirectorySecurity
    $acl.SetAccessRuleProtection($true,$false)
    $current = [Security.Principal.WindowsIdentity]::GetCurrent()
    try {
        foreach ($sid in @($current.User.Value,'S-1-5-18','S-1-5-32-544')) {
            $identity = New-Object Security.Principal.SecurityIdentifier($sid)
            $rule = New-Object Security.AccessControl.FileSystemAccessRule($identity,'FullControl','ContainerInherit,ObjectInherit','None','Allow')
            [void]$acl.AddAccessRule($rule)
        }
        [IO.Directory]::SetAccessControl($Path,$acl)
    } finally { $current.Dispose() }
}
function Get-ADMigrationHash {
    param([string]$Path)
    $filePath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path)
    $stream = [IO.File]::OpenRead($filePath)
    try { (Get-FileHash -InputStream $stream -Algorithm SHA256).Hash }
    finally { $stream.Dispose() }
}
function Write-ADMigrationJson {
    param($Value, [string]$Path)
    # Same-directory replace keeps state updates atomic on supported Windows filesystems.
    $temp = $Path + '.' + [guid]::NewGuid().ToString('N') + '.tmp'
    $json = ConvertTo-Json -InputObject $Value -Depth 100
    [IO.File]::WriteAllText($temp, $json, (New-Object Text.UTF8Encoding($false)))
    if ([IO.File]::Exists($Path)) {
        # Windows PowerShell 5.1 can marshal $null as an empty string for
        # the backup filename. Use a real, unique sibling path instead.
        $backup = $Path + '.' + [guid]::NewGuid().ToString('N') + '.bak'
        [IO.File]::Replace($temp, $Path, $backup)
        # Delete the previous version only after replacement succeeds.
        [IO.File]::Delete($backup)
    }
    else { [IO.File]::Move($temp, $Path) }
}
function Read-ADMigrationInput {
    param([string]$CsvPath,[string]$ConfigPath,[string]$GroupMapPath)
    foreach ($path in @($CsvPath,$ConfigPath,$GroupMapPath)) {
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "File not found: $path" }
    }
    $rows = @(Import-Csv -LiteralPath $CsvPath)
    if ($rows.Count -ne 1) { throw 'V1 requires exactly ONE CSV data row. No rows will be silently dropped.' }
    $row = $rows[0]
    foreach ($column in @('SamAccountName','MigrationDirection','TargetOU','ChangeReference')) {
        if ($row.PSObject.Properties.Name -notcontains $column) { throw "Missing CSV column: $column" }
        $row.$column = ([string]$row.$column).Trim()
    }
    if ($row.SamAccountName -notmatch '^[A-Za-z0-9._-]{1,20}$' -or $row.SamAccountName -match 'REPLACE') {
        throw 'Supply the source sAMAccountName, not a placeholder. V1 accepts letters, numbers, dot, underscore and hyphen.'
    }
    if ($row.ChangeReference -notmatch '^[A-Za-z][A-Za-z0-9]*-\d+$') { throw 'Supply a change reference such as CHANGE-101.' }
    $directions = @('ROOT_TO_CHILD','CHILD_TO_ROOT')
    if ($row.MigrationDirection -cnotin $directions) { throw 'Invalid MigrationDirection.' }
    $config = Get-Content -LiteralPath $ConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $dnsName = '^(?=.{1,253}$)(?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?$'
    $forestRoot = [string]$config.ForestRoot
    $childDomain = [string]$config.ChildDomain
    if ($config.SchemaVersion -ne 1 -or $forestRoot -notmatch $dnsName -or $childDomain -notmatch $dnsName -or
        ($childDomain -split '\.',2)[1] -ne $forestRoot) { throw 'Configure a forest-root FQDN and its direct child domain.' }
    foreach ($name in $directions) {
        $pair = Get-ADMigrationOptionalProperty $config.Directions $name
        $source, $target = if ($name -eq 'ROOT_TO_CHILD') { $forestRoot, $childDomain } else { $childDomain, $forestRoot }
        if ($null -eq $pair -or $pair.SourceDomain -ne $source -or $pair.TargetDomain -ne $target) { throw "Direction $name must match the configured forest root and child domains." }
    }
    $direction = $config.Directions.($row.MigrationDirection)
    foreach ($class in @($config.ApprovedChildObjectClasses)) {
        if ($class -notmatch '^[A-Za-z][A-Za-z0-9-]*$') { throw 'Child allowlist requires exact schema class names; no wildcards.' }
    }
    if (-not $row.TargetOU) { $row.TargetOU = $direction.DefaultTargetOU }
    $targetSuffix = ',DC=' + ($direction.TargetDomain -replace '\.',',DC=')
    $domainComponents = [regex]::Match($row.TargetOU,'(?i)(?<!\\)(?:,DC=[a-z0-9-]+)+$').Value
    if ($row.TargetOU -notmatch '^OU=' -or $domainComponents -ne $targetSuffix) { throw 'TargetOU must be an OU distinguished name in the selected target domain.' }
    $mapHeader = Get-Content -LiteralPath $GroupMapPath -TotalCount 1
    $probe = @($mapHeader, 'probe,probe,probe,probe,probe,probe') | ConvertFrom-Csv
    foreach ($field in @('MigrationDirection','SourceGroupSID','TargetGroupSID','Action','ApprovedBy','ApprovalReference')) {
        if ($probe.PSObject.Properties.Name -notcontains $field) { throw "Missing mapping column: $field" }
    }
    $maps = @(Import-Csv -LiteralPath $GroupMapPath)
    $keys = @{}
    foreach ($map in $maps) {
        foreach ($field in @('MigrationDirection','SourceGroupSID','TargetGroupSID','Action','ApprovedBy','ApprovalReference')) {
            if ($map.PSObject.Properties.Name -notcontains $field) { throw "Missing mapping column: $field" }
            $map.$field = ([string]$map.$field).Trim()
        }
        if ($map.MigrationDirection -cnotin $directions) { throw 'Invalid mapping direction.' }
        if ($map.SourceGroupSID -notmatch '^S-1-5-21-\d+-\d+-\d+-\d+$') { throw 'Mappings require exact source domain group SIDs.' }
        if ($map.Action -cnotin @('Map','Retain','Omit')) { throw 'Mapping Action must be Map, Retain or Omit.' }
        if (-not $map.ApprovedBy -or -not $map.ApprovalReference) { throw 'Mappings require ApprovedBy and ApprovalReference.' }
        if ($map.Action -eq 'Map' -and $map.TargetGroupSID -notmatch '^S-1-5-21-\d+-\d+-\d+-\d+$') { throw 'Map requires a target domain group SID.' }
        if ($map.Action -ne 'Map' -and $map.TargetGroupSID) { throw 'Retain/Omit must have an empty TargetGroupSID.' }
        $scope = [string](Get-ADMigrationOptionalProperty $map 'SourceUserGUID')
        if ($scope -and $scope -notmatch '^[0-9a-fA-F]{8}(-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}$') { throw 'Invalid SourceUserGUID mapping scope.' }
        if ($map.Action -eq 'Omit' -and (-not $scope -or -not (Get-ADMigrationOptionalProperty $map 'ChangeReference'))) { throw 'Omit requires SourceUserGUID and ChangeReference for this account.' }
        $key = $map.MigrationDirection + '|' + $map.SourceGroupSID + '|' + $scope
        if ($keys.ContainsKey($key)) { throw "Duplicate group mapping: $key" }
        $keys[$key] = $true
    }
    [pscustomobject]@{ Row=$row; Config=$config; Direction=$direction; Maps=$maps
        CsvHash=(Get-ADMigrationHash $CsvPath); ConfigHash=(Get-ADMigrationHash $ConfigPath); MapHash=(Get-ADMigrationHash $GroupMapPath) }
}
function Add-UserMigrationFinding {
    param($Context,[string]$Code,[string]$Severity,[string]$Message)
    $entry = [pscustomobject]@{ TimeUtc=[datetime]::UtcNow.ToString('o'); Code=$Code; Severity=$Severity; Message=$Message }
    $Context.Findings.Add($entry)
    $color='Gray'
    if ($Severity -eq 'Blocker') { $color='Yellow' }
    if ($Severity -eq 'Pass') { $color='Green' }
    Write-Host ('[{0}] {1}: {2}' -f $Severity,$Code,$Message) -ForegroundColor $color
    $entry | ConvertTo-Json -Compress | Add-Content -LiteralPath $Context.LogPath -Encoding UTF8
}
function Set-UserMigrationStage {
    param($Context,[string]$Stage)
    Write-ADMigrationSection ('AUDIT STEP: '+$Stage)
    $Context.State.Stage = $Stage
    $Context.State.UpdatedUtc = [datetime]::UtcNow.ToString('o')
    Write-ADMigrationJson $Context.State $Context.StatePath
}
function Get-ADMigrationDomainForDN {
    param([string]$DN,$Domains)
    $matches = @($Domains | Where-Object { $DN.EndsWith(',' + $_.DistinguishedName,[StringComparison]::OrdinalIgnoreCase) } | Sort-Object { $_.DistinguishedName.Length } -Descending)
    if (-not $matches.Count) { throw "Cannot resolve domain for $DN" }
    $matches[0]
}
function Test-ADMigrationOperator {
    param($Domains,$RootDomain)
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    try {
        $principal = New-Object Security.Principal.WindowsPrincipal($identity)
        $sid = $identity.User.Value
        $domain = @($Domains | Where-Object { $_.DomainSID.Value -eq $identity.User.AccountDomainSid.Value })
        if ($domain.Count -ne 1) { throw 'Operator must be a domain user in this forest, not a local or foreign account.' }
        $operator = Get-ADUser -Identity $sid -Server $domain[0].RIDMaster -Properties Enabled
        $auth = @(Get-ADAccountAuthorizationGroup -Identity $operator -Server $domain[0].RIDMaster)
        $authSids = @($auth | ForEach-Object { $_.SID.Value })
        $tokenSids = @($identity.Groups | ForEach-Object { $_.Value })
        $eaSid = $RootDomain.DomainSID.Value + '-519'
        $protectedSids = @($Domains | ForEach-Object { $_.DomainSID.Value + '-525' })
        [pscustomobject]@{
            Name=$identity.Name; SID=$sid; Enabled=$operator.Enabled
            EnterpriseAdminsSID=$eaSid; DirectoryEnterpriseAdmin=($authSids -contains $eaSid)
            EnabledTokenEnterpriseAdmin=$principal.IsInRole((New-Object Security.Principal.SecurityIdentifier($eaSid)))
            Elevated=$principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
            DirectoryProtectedUsers=(@($authSids | Where-Object { $protectedSids -contains $_ }).Count -gt 0)
            TokenProtectedUsers=(@($tokenSids | Where-Object { $protectedSids -contains $_ }).Count -gt 0)
            DirectorySecurityGroupSIDs=$authSids; TokenGroupSIDs=$tokenSids
        }
    } finally { $identity.Dispose() }
}
function Get-ADMigrationDirectGroups {
    param($User,$Domains,$SourceDomain)
    $groups = @{}
    $userDN = ConvertTo-ADMigrationLdapValue $User.DistinguishedName
    $sidBytes = New-Object byte[] ($User.SID.BinaryLength)
    $User.SID.GetBinaryForm($sidBytes,0)
    $ldapSid = ($sidBytes | ForEach-Object { '\{0:x2}' -f $_ }) -join ''
    foreach ($domain in $Domains) {
        # Query every domain NC, including foreign-security-principal representations.
        $fsp = @(Get-ADObject -LDAPFilter "(&(objectClass=foreignSecurityPrincipal)(objectSid=$ldapSid))" -Server $domain.RIDMaster -SearchBase $domain.DistinguishedName)
        $memberFilters = '(member=' + $userDN + ')'
        foreach ($object in $fsp) { $memberFilters += '(member=' + (ConvertTo-ADMigrationLdapValue $object.DistinguishedName) + ')' }
        $filter = '(&(objectClass=group)(|' + $memberFilters + '))'
        foreach ($group in @(Get-ADGroup -LDAPFilter $filter -Server $domain.RIDMaster -SearchBase $domain.DistinguishedName -Properties Description)) {
            $groups[$group.SID.Value] = [pscustomobject]@{ Name=$group.Name; ObjectGUID=$group.ObjectGUID.ToString(); SID=$group.SID.Value; DistinguishedName=$group.DistinguishedName; Domain=$domain.DNSRoot; Scope=[string]$group.GroupScope; Category=[string]$group.GroupCategory; IsPrimary=$false; Description=$group.Description }
        }
    }
    $primarySID = $SourceDomain.DomainSID.Value + '-' + $User.primaryGroupID
    $primary = Get-ADGroup -Identity $primarySID -Server $SourceDomain.RIDMaster -Properties Description
    $groups[$primarySID] = [pscustomobject]@{ Name=$primary.Name; ObjectGUID=$primary.ObjectGUID.ToString(); SID=$primarySID; DistinguishedName=$primary.DistinguishedName; Domain=$SourceDomain.DNSRoot; Scope=[string]$primary.GroupScope; Category=[string]$primary.GroupCategory; IsPrimary=$true; Description=$primary.Description }
    @($groups.Values | Sort-Object Domain,Name)
}
function Get-ADMigrationMappingAnalysis {
    param($Groups,$InputData,$Target,$Context)
    foreach ($group in $Groups) {
        $status='Unmapped'; $candidate=''; $candidateSID=''; $approval=''; $action='Review'; $reason='Explicit disposition required.'
        $map = @($InputData.Maps | Where-Object { $_.MigrationDirection -eq $InputData.Row.MigrationDirection -and $_.SourceGroupSID -eq $group.SID -and
            (-not (Get-ADMigrationOptionalProperty $_ 'SourceUserGUID') -or
              ([string](Get-ADMigrationOptionalProperty $_ 'SourceUserGUID') -eq [string]$Context.State.SourceGUID -and
               [string](Get-ADMigrationOptionalProperty $_ 'ChangeReference') -eq $InputData.Row.ChangeReference)) })
        if ($map.Count -gt 1) { throw 'Multiple applicable group dispositions. Resolve configuration before continuing.' }
        if ($group.IsPrimary) {
            $status='PrimaryGroupReview'; $action='Review'; $reason='Primary group requires target-domain handling; not an ordinary member link.'
        } elseif ($map.Count -eq 1) {
            $action=$map[0].Action; $approval=$map[0].ApprovedBy + ' / ' + $map[0].ApprovalReference
            if ($action -eq 'Map') {
                try {
                    $targetSidPrefix = $Target.DomainSID.Value + '-'
                    if (-not $map[0].TargetGroupSID.StartsWith($targetSidPrefix,[StringComparison]::OrdinalIgnoreCase)) { throw 'Mapped group SID is not from the target domain.' }
                    $mapped = Get-ADGroup -Identity $map[0].TargetGroupSID -Server $Target.RIDMaster
                    if (-not $mapped.DistinguishedName.EndsWith(','+$Target.DistinguishedName,[StringComparison]::OrdinalIgnoreCase)) { throw 'Mapped group is outside target domain.' }
                    $candidate=$mapped.DistinguishedName; $candidateSID=[string](Get-ADMigrationOptionalProperty $mapped 'SID'); $status='ConfiguredMapping'; $reason='Exact target SID resolved; approval metadata recorded.'
                    if ($group.Category -ne [string]$mapped.GroupCategory) { $status='CategoryMismatch'; $reason='Security/distribution category differs.' }
                } catch { $status='MappingInvalid'; $reason=$_.Exception.Message }
            } elseif ($action -eq 'Retain') {
                $candidate=$group.DistinguishedName; $candidateSID=$group.SID; $status='ConfiguredRetain'; $reason='Explicit retain requested; post-move membership still requires verification.'
                if ($group.Scope -eq 'Global' -and $group.Domain -ne $Target.DNSRoot) { $status='ScopeConflict'; $reason='Global group cannot contain a user from the target domain.' }
            } else { $status='ConfiguredOmit'; $reason='Explicit omission recorded, no membership changes in V1.' }
        } elseif (Test-ADMigrationRetentionScope $group $Target.DNSRoot) {
            $candidate=$group.DistinguishedName; $candidateSID=$group.SID
            $status='SameGroupRetentionReview'; $action='ReviewRetain'
            $reason='Existing group identity supports target-domain membership by scope. Review intended access and verify membership after any future move; no replacement required by scope alone.'
        } else {
            $name=ConvertTo-ADMigrationLdapValue $group.Name
            $candidates=@(Get-ADGroup -LDAPFilter "(name=$name)" -SearchBase $Target.DistinguishedName -Server $Target.RIDMaster)
            if ($candidates.Count -eq 1) { $candidate=$candidates[0].DistinguishedName; $candidateSID=[string](Get-ADMigrationOptionalProperty $candidates[0] 'SID'); $status='ExactNameCandidate'; $reason='Name equality is a suggestion only; approve a SID mapping.' }
            elseif ($candidates.Count -gt 1) { $status='AmbiguousName'; $reason='Multiple target groups have this name.' }
        }
        if ($status -notin @('ConfiguredMapping','ConfiguredRetain','ConfiguredOmit')) {
            $severity = 'Blocker'
            if ($status -eq 'SameGroupRetentionReview') { $severity = 'Review' }
            if ($group.IsPrimary -and $group.SID -match '-513$') { $severity = 'Review' }
            Add-UserMigrationFinding $Context 'GroupDispositionReview' $severity ($group.Name + ': ' + $status + '. ' + $reason)
        }
        $catalog = Get-ADMigrationOptionalProperty (Get-ADMigrationOptionalProperty $InputData 'Config') 'GroupCatalog'
        $family = @((Get-ADMigrationOptionalProperty $catalog 'Prefixes') | Where-Object { $_ -and $group.Name.StartsWith($_,[StringComparison]::OrdinalIgnoreCase) } | Select-Object -First 1)
        if (-not $family.Count) { $family = @('Other') }
        [pscustomobject]@{ SourceName=$group.Name; SourceSID=$group.SID; SourceDomain=$group.Domain; Scope=$group.Scope; IsPrimary=$group.IsPrimary; ApplicationFamily=$family[0]; Action=$action; Status=$status; TargetDN=$candidate; TargetSID=$candidateSID; Approval=$approval; Reason=$reason }
    }
}
function Export-ADMigrationReports {
    param($Context,$InputData)
    $blocked = @($Context.Findings | Where-Object Severity -eq 'Blocker').Count -gt 0
    $Context.State.Status = $(if ($blocked) { 'Blocked' } else { 'ReviewRequired' })
    $Context.State.Stage = 'AuditCompleted'
    $Context.State.UpdatedUtc = [datetime]::UtcNow.ToString('o')
    $report = [ordered]@{
        ToolVersion='1.0.13'; RunID=$Context.State.RunID; Mode='ReadOnly'; RealExecutionAvailable=$false
        Status=$Context.State.Status; Input=$InputData.Row; State=$Context.State
        Operator=$Context.Operator; SourceRIDMaster=$Context.SourceRID; TargetRIDMaster=$Context.TargetRID
        Findings=@($Context.Findings.ToArray()); Groups=@($Context.Groups); GroupMappings=@($Context.Mappings); ChildObjects=@($Context.Children)
        Limitations=@('No move readiness certification. Human review required.','Snapshot contains readable properties, not passwords, secret attributes, or a restorable AD backup.','Effective ACL rights and replication convergence are not proven.','No post-migration verification was performed.')
    }
    Write-ADMigrationJson $report (Join-Path $Context.Directory 'PreMigration.json')
    $plan=[ordered]@{
        SchemaVersion=1; RunID=$Context.State.RunID; SourceGUID=$Context.State.SourceGUID
        User=$InputData.Row.SamAccountName; ChangeReference=$InputData.Row.ChangeReference
        SourceDomain=$InputData.Direction.SourceDomain; TargetDomain=$InputData.Direction.TargetDomain
        SourceRIDMaster=$Context.SourceRID; TargetRIDMaster=$Context.TargetRID; TargetOU=$InputData.Row.TargetOU
        Status='ReviewOnly'; ExecutionAvailable=$false; ConflictPolicy='Block; never merge'
        ChildCleanup='Required for ActiveSync; use separate cleanup entry point'; AccountMove='Disabled'; GroupReconciliation='AnalysisOnly'
        RoamingProfileTranslation='ExcludedByRequest'; UpdateUserRights='ExcludedByRequest'; MigrateGroupObjects='ExcludedByRequest'
        MetadataStamp='Disabled; no attribute selected or reserved'
        HomeDriveAction='Manual per runbook after a future approved migration'
        ChangeTrackingAction='Draft only'; Findings=@($Context.Findings.ToArray())
    }
    Write-ADMigrationJson $plan (Join-Path $Context.Directory 'MigrationPlan.json')
    $Context.Findings.ToArray() | Export-Csv -LiteralPath (Join-Path $Context.Directory 'Findings.csv') -NoTypeInformation -Encoding UTF8
    $Context.Groups | Export-Csv -LiteralPath (Join-Path $Context.Directory 'DirectGroups.csv') -NoTypeInformation -Encoding UTF8
    $Context.Mappings | Export-Csv -LiteralPath (Join-Path $Context.Directory 'GroupMappingAnalysis.csv') -NoTypeInformation -Encoding UTF8
    $Context.Mappings | Where-Object { $_.Status -notin @('ConfiguredMapping','ConfiguredRetain','ConfiguredOmit','PrimaryGroupReview','SameGroupRetentionReview') } | Export-Csv -LiteralPath (Join-Path $Context.Directory 'UnmatchedGroups.csv') -NoTypeInformation -Encoding UTF8
    $Context.Children | Export-Csv -LiteralPath (Join-Path $Context.Directory 'ChildObjects.csv') -NoTypeInformation -Encoding UTF8
    $checks = @('Source absence and target GUID identity','Target DN, UPN and sAMAccountName','Password sign-in and expected SIDHistory','Direct/primary group reconciliation','Application access','Home-drive access and permissions','Enterprise Admin removal and Protected Users restoration','Change tracking and stakeholder completion')
    Write-ADMigrationJson ([ordered]@{ SchemaVersion=1; RunID=$Context.State.RunID; MigrationPerformed=$false; Status='NotRun'; Checks=@($checks | ForEach-Object { [pscustomobject]@{ Check=$_; Status='NotRun'; Evidence=$null; VerifiedBy=$null; VerifiedUtc=$null } }) }) (Join-Path $Context.Directory 'PostMigration.template.json')
    $body = '<h1>AD user migration preflight</h1><p><strong>READ ONLY: no account was migrated.</strong></p>'
    $body += '<p>Status: ' + $Context.State.Status + '. Human review is required. See JSON and CLIXML for complete evidence.</p>'
    $body += ($InputData.Row | ConvertTo-Html -Fragment | Out-String)
    $body += '<h2>Findings</h2>' + ($Context.Findings.ToArray() | ConvertTo-Html -Fragment | Out-String)
    $body += '<h2>Group analysis</h2>' + ($Context.Mappings | ConvertTo-Html -Fragment | Out-String)
    $body += '<h2>Additional evidence</h2><p>Review GroupCatalogSummary.json for discovery completeness; GroupCatalog.csv, GroupNesting.csv and GroupMatchCandidates.csv for naming/nesting candidates; SourceConsistency.json for initial/final USN evidence; ChildCleanupPlan.json for mandatory ActiveSync cleanup. Execution is disabled in this audit entry point.</p>'
    $body += '<h2>Child objects</h2>' + ($Context.Children | ConvertTo-Html -Fragment | Out-String)
    $html = ConvertTo-Html -Title 'AD user migration preflight' -Head '<meta charset="utf-8"><style>body{font:14px Segoe UI;margin:30px;color:#172b4d}table{border-collapse:collapse;width:100%;margin-bottom:24px}th,td{border:1px solid #cbd5e1;padding:7px;text-align:left;overflow-wrap:anywhere}th{background:#e7eff8}</style>' -Body $body
    $html | Set-Content -LiteralPath (Join-Path $Context.Directory 'PreMigration.html') -Encoding UTF8
    @"
Change tracking: $($InputData.Row.ChangeReference)
READ-ONLY AUDIT ASSESSMENT: $($InputData.Row.SamAccountName)
Direction: $($InputData.Row.MigrationDirection)
Assessment: $($Context.State.Status)
Run ID: $($Context.State.RunID)
No user move, child deletion, membership update, password operation, home-drive copy, or notification was performed.
Review PreMigration.html, Findings.csv, GroupMappingAnalysis.csv and ChildObjects.csv.

COMPLETION TEMPLATE ONLY - DO NOT POST AS COMPLETED
Migration result: NOT PERFORMED
Identity and target OU verification: NOT RUN
Password and application testing: NOT RUN
Group reconciliation: NOT RUN
home-drive data and ACL verification: NOT RUN
Stakeholder notification: NOT CONFIRMED
Temporary administrator access cleanup: NOT CONFIRMED
Operator / completion time / evidence: TO BE ENTERED AFTER A FUTURE APPROVED MIGRATION
"@ | Set-Content -LiteralPath (Join-Path $Context.Directory 'ChangeSummary.txt') -Encoding UTF8
    Write-ADMigrationJson $Context.State $Context.StatePath
    $manifest = @(Get-ChildItem -LiteralPath $Context.Directory -File | Where-Object Name -ne 'EvidenceHashes.json' | ForEach-Object {
        [pscustomobject]@{ FileName=$_.Name; SHA256=(Get-ADMigrationHash $_.FullName); Bytes=$_.Length }
    })
    Write-ADMigrationJson $manifest (Join-Path $Context.Directory 'EvidenceHashes.json')
}
function Invoke-ADMigrationAudit {
    [CmdletBinding()]
    param($InputData,[string]$OutputRoot,[string]$ResumeState)
    $prior=$null
    if ($ResumeState) {
        $prior=Get-Content -LiteralPath $ResumeState -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($prior.SchemaVersion -ne 1 -or $prior.ToolVersion -ne '1.0.13' -or $prior.Mode -ne 'ReadOnly') { throw 'Unsupported resume state.' }
        foreach ($key in @('CsvHash','ConfigHash','MapHash')) { if ($prior.$key -ne $InputData.$key) { throw "Resume rejected: $key changed. Start a fresh audit without -ResumeState." } }
    }
    $runID=[datetime]::UtcNow.ToString('yyyyMMddTHHmmssfffZ')+'-'+[guid]::NewGuid().ToString('N').Substring(0,8)
    $directory=Join-Path $OutputRoot $runID
    [void][IO.Directory]::CreateDirectory($directory)
    Protect-ADMigrationDirectory $directory
    $context=[pscustomobject]@{
        Directory=$directory; StatePath=(Join-Path $directory 'state.json'); LogPath=(Join-Path $directory 'Audit.jsonl')
        Findings=(New-Object 'System.Collections.Generic.List[object]'); Operator=$null; SourceRID=$null; TargetRID=$null
        Groups=@(); Mappings=@(); Children=@()
        State=[ordered]@{ SchemaVersion=1; ToolVersion='1.0.13'; RunID=$runID; Mode='ReadOnly'; Status='Running'; Stage='Initialize'; UpdatedUtc=[datetime]::UtcNow.ToString('o'); CsvHash=$InputData.CsvHash; ConfigHash=$InputData.ConfigHash; MapHash=$InputData.MapHash; SourceGUID=$null; PreviousRunID=$(if ($prior) { $prior.RunID } else { $null }) }
    }
    Write-ADMigrationJson $context.State $context.StatePath
    try {
        Set-UserMigrationStage $context 'Prerequisites'
        if (-not (Get-Module -ListAvailable -Name ActiveDirectory)) { throw 'ActiveDirectory module not installed. Install RSAT AD PowerShell using your approved process.' }
        Import-Module ActiveDirectory -ErrorAction Stop
        Add-UserMigrationFinding $context 'Module' 'Pass' 'ActiveDirectory module loaded.'
        $forest=Get-ADForest -Server $InputData.Config.ForestRoot
        if ($forest.RootDomain -ne $InputData.Config.ForestRoot) { throw 'Unexpected forest root.' }
        $domains=@(foreach ($dns in $forest.Domains) { Get-ADDomain -Identity $dns -Server $dns })
        $source=@($domains | Where-Object DNSRoot -eq $InputData.Direction.SourceDomain)
        $target=@($domains | Where-Object DNSRoot -eq $InputData.Direction.TargetDomain)
        $root=@($domains | Where-Object DNSRoot -eq $forest.RootDomain)
        if ($source.Count -ne 1 -or $target.Count -ne 1 -or $root.Count -ne 1) { throw 'Source/target/root must resolve in the same forest.' }
        $source=$source[0]; $target=$target[0]; $root=$root[0]
        $context.SourceRID=$source.RIDMaster; $context.TargetRID=$target.RIDMaster
        Write-Host ('Source domain : '+$source.DNSRoot)
        Write-Host ('Source RID    : '+$source.RIDMaster)
        Write-Host ('Target domain : '+$target.DNSRoot)
        Write-Host ('Target RID    : '+$target.RIDMaster)
        Write-Host ('Target OU     : '+$InputData.Row.TargetOU)
        foreach ($domain in @($source,$target)) {
            $dc=Get-ADDomainController -Identity $domain.RIDMaster -Server $domain.DNSRoot
            $dse=Get-ADRootDSE -Server $domain.RIDMaster
            if ($dc.IsReadOnly -or $dse.defaultNamingContext -ne $domain.DistinguishedName -or @($dc.OperationMasterRoles) -notcontains 'RIDMaster') { throw "Invalid RID Master endpoint: $($domain.RIDMaster)" }
        }
        Export-ADMigrationSnapshot -Objects @($domains) -Path (Join-Path $directory 'Domains.clixml')
        Add-UserMigrationFinding $context 'RIDMasters' 'Pass' 'Writable source/target RID Master endpoints discovered and queried.'
        $context.Operator=Test-ADMigrationOperator -Domains $domains -RootDomain $root
        Write-ADMigrationJson $context.Operator (Join-Path $directory 'Operator.json')
        if (-not $context.Operator.Enabled -or -not $context.Operator.DirectoryEnterpriseAdmin -or -not $context.Operator.EnabledTokenEnterpriseAdmin -or -not $context.Operator.Elevated) {
            Add-UserMigrationFinding $context 'OperatorAuthorization' 'Blocker' 'Enabled account, directory Enterprise Admin membership, enabled EA token and elevated process are required. Follow runbook approval; sign out/in after membership changes.'
        }
        if ($context.Operator.DirectoryProtectedUsers -or $context.Operator.TokenProtectedUsers) {
            Add-UserMigrationFinding $context 'OperatorProtectedUsers' 'Blocker' 'Protected Users exists in directory membership or current token. V1 does not remove it. Follow your approved runbook and refresh the logon session.'
        }
        if (@($context.Findings | Where-Object Severity -eq 'Blocker').Count) { throw 'Administrator validation failed; user assessment not started.' }
        Add-UserMigrationFinding $context 'OperatorAuthorization' 'Pass' 'Directory membership, enabled current token, elevation and Protected Users checks passed.'
        Set-UserMigrationStage $context 'SourceSnapshot'
        $sam=ConvertTo-ADMigrationLdapValue $InputData.Row.SamAccountName
        $users=@(Invoke-ADMigrationMeasuredRead $context 'Snapshot.QueryUser' { Get-ADUser -LDAPFilter "(sAMAccountName=$sam)" -SearchBase $source.DistinguishedName -Server $source.RIDMaster -Properties * })
        if ($users.Count -ne 1) { throw "Expected one source user, found $($users.Count)." }
        $user=$users[0]
        $sourceReadServer=[string]$source.RIDMaster
        $sourceReadGuid=[guid]$user.ObjectGUID
        $initialUSN=Get-ADMigrationUSNObservation -Value $user.uSNChanged -Server $sourceReadServer -ObjectGUID $sourceReadGuid -Label 'InitialGetADUser'
        Write-ADMigrationJson $initialUSN (Join-Path $directory 'SourceUSN.Initial.json')
        if ($prior -and $prior.SourceGUID -and $prior.SourceGUID -ne $user.ObjectGUID.ToString()) { throw 'Source GUID changed since previous audit. Stop and investigate identity replacement.' }
        $context.State.SourceGUID=$user.ObjectGUID.ToString()
        Invoke-ADMigrationMeasuredRead $context 'Snapshot.ExportUser' { Export-ADMigrationSnapshot -Objects @($user) -Path (Join-Path $directory 'UserSnapshot.clixml') }
        $summary=[ordered]@{ SnapshotUtc=[datetime]::UtcNow.ToString('o'); SourceRIDMaster=$source.RIDMaster; SourceDomain=$source.DNSRoot }
        foreach ($property in @('SamAccountName','ObjectGUID','SID','SIDHistory','DistinguishedName','CanonicalName','UserPrincipalName','mail','proxyAddresses','employeeID','DisplayName','Description','Enabled','AccountExpirationDate','PasswordLastSet','pwdLastSet','userAccountControl','primaryGroupID','homeDirectory','homeDrive','profilePath','department','company','manager','telephoneNumber','mobile','memberOf','uSNChanged')) {
            $value=Get-ADMigrationOptionalProperty $user $property
            $summary[$property]=@($value | ForEach-Object { [string]$_ })
        }
        for ($i=1; $i -le 15; $i++) { $property='extensionAttribute'+$i; $summary[$property]=@(Get-ADMigrationOptionalProperty $user $property | ForEach-Object { [string]$_ }) }
        Write-ADMigrationJson $summary (Join-Path $directory 'UserSummary.json')
        $raw=Invoke-ADMigrationMeasuredRead $context 'Snapshot.QueryRawAttributes' { Get-ADObject -Identity $user.DistinguishedName -Server $source.RIDMaster -Properties * }
        $rawUSN=Get-ADMigrationUSNObservation -Value $raw.uSNChanged -Server $sourceReadServer -ObjectGUID $sourceReadGuid -Label 'InitialGetADObject'
        Invoke-ADMigrationMeasuredRead $context 'Snapshot.ExportRawAttributes' { Export-ADMigrationSnapshot -Objects @($raw) -Path (Join-Path $directory 'UserRawAttributes.clixml') }
        if (Get-ADMigrationOptionalProperty $user 'nTSecurityDescriptor') { $user.nTSecurityDescriptor.GetSecurityDescriptorSddlForm([Security.AccessControl.AccessControlSections]::All) | Set-Content -LiteralPath (Join-Path $directory 'UserSecurityDescriptor.txt') -Encoding UTF8 }
        Set-UserMigrationStage $context 'SourceValidation'
        Add-UserMigrationFinding $context 'Snapshot' 'Pass' 'All properties returned by Get-ADUser/Get-ADObject -Properties * exported as normalized CLIXML and JSON; inaccessible/secret attributes are not included.'
        if (-not $user.Enabled) { Add-UserMigrationFinding $context 'SourceDisabled' 'Blocker' 'Source user is disabled; review account selection.' }
        if ((Get-ADMigrationOptionalProperty $user 'adminCount') -eq 1 -or $user.SID.Value -eq $context.Operator.SID) { Add-UserMigrationFinding $context 'PrivilegedSource' 'Blocker' 'Source is adminCount=1 or the operator account; excluded from this workflow.' }
        if (Get-ADMigrationOptionalProperty $user 'ProtectedFromAccidentalDeletion') { Add-UserMigrationFinding $context 'DeletionProtection' 'Blocker' 'Source has accidental deletion protection. No protection changes are implemented.' }
        $userAuth=@(Get-ADAccountAuthorizationGroup -Identity $user -Server $source.RIDMaster)
        Export-ADMigrationSnapshot -Objects @($userAuth) -Path (Join-Path $directory 'UserAuthorizationGroups.clixml')
        $protected=@($domains | ForEach-Object { $_.DomainSID.Value + '-525' })
        $privileged=@('S-1-5-32-544','S-1-5-32-548','S-1-5-32-549','S-1-5-32-550','S-1-5-32-551')
        foreach ($d in $domains) { foreach ($rid in @(512,518,519,520)) { $privileged += $d.DomainSID.Value + '-' + $rid } }
        if (@($userAuth | Where-Object { $protected -contains $_.SID.Value }).Count) { Add-UserMigrationFinding $context 'SourceProtectedUsers' 'Blocker' 'Source user belongs to Protected Users. Human review required; no membership changes made.' }
        if (@($userAuth | Where-Object { $privileged -contains $_.SID.Value }).Count) { Add-UserMigrationFinding $context 'PrivilegedSourceGroups' 'Blocker' 'Source account has privileged authorization group membership.' }
        Set-UserMigrationStage $context 'TargetValidation'
        try {
            $ou=Get-ADOrganizationalUnit -Identity $InputData.Row.TargetOU -Server $target.RIDMaster -Properties ProtectedFromAccidentalDeletion
            $owner=Get-ADMigrationDomainForDN -DN $ou.DistinguishedName -Domains $domains
            if ($owner.DNSRoot -ne $target.DNSRoot) { throw 'Target OU belongs to a different domain.' }
            Export-ADMigrationSnapshot -Objects @($ou) -Path (Join-Path $directory 'TargetOU.clixml')
            $cn=ConvertTo-ADMigrationLdapValue $user.Name
            $cnHits=@(Get-ADObject -LDAPFilter "(name=$cn)" -SearchBase $ou.DistinguishedName -SearchScope OneLevel -Server $target.RIDMaster)
            if ($cnHits.Count) { Add-UserMigrationFinding $context 'TargetRDNConflict' 'Blocker' 'An object with the source name already exists directly in the target OU.' }
            Add-UserMigrationFinding $context 'TargetOU' 'Pass' 'Target OU exists in expected domain. Effective create/move ACL rights are not proven by V1.'
        } catch { Add-UserMigrationFinding $context 'TargetOU' 'Blocker' $_.Exception.Message }
        $samHits=@(Get-ADObject -LDAPFilter "(sAMAccountName=$sam)" -SearchBase $target.DistinguishedName -Server $target.RIDMaster)
        if ($samHits.Count) { Add-UserMigrationFinding $context 'TargetSamConflict' 'Blocker' 'Target domain contains this sAMAccountName (any object class).' }
        $identityFilters=@()
        if ($user.UserPrincipalName) { $identityFilters += '(userPrincipalName='+(ConvertTo-ADMigrationLdapValue $user.UserPrincipalName)+')' }
        $mail=Get-ADMigrationOptionalProperty $user 'mail'
        if ($mail) { $identityFilters += '(mail='+(ConvertTo-ADMigrationLdapValue $mail)+')' }
        foreach ($spn in @(Get-ADMigrationOptionalProperty $user 'ServicePrincipalNames')) { $identityFilters += '(servicePrincipalName='+(ConvertTo-ADMigrationLdapValue $spn)+')' }
        foreach ($proxy in @(Get-ADMigrationOptionalProperty $user 'proxyAddresses')) { $identityFilters += '(proxyAddresses='+(ConvertTo-ADMigrationLdapValue $proxy)+')' }
        if ($identityFilters.Count) {
            foreach ($domain in $domains) {
                $hits=@(Get-ADObject -LDAPFilter ('(|'+($identityFilters -join '')+')') -SearchBase $domain.DistinguishedName -Server $domain.RIDMaster | Where-Object { $_.ObjectGUID -ne $user.ObjectGUID })
                if ($hits.Count) {
                    Export-ADMigrationSnapshot -Objects @($hits) -Path (Join-Path $directory ('IdentityConflicts.'+$domain.DNSRoot+'.clixml'))
                    Add-UserMigrationFinding $context 'ForestIdentityConflict' 'Blocker' ('UPN/mail/SPN/proxyAddress collision in '+$domain.DNSRoot+'; see evidence.')
                }
            }
        }
        Set-UserMigrationStage $context 'Groups'
        $context.Groups=@(Get-ADMigrationDirectGroups -User $user -Domains $domains -SourceDomain $source)
        $context.Mappings=@(Get-ADMigrationMappingAnalysis -Groups $context.Groups -InputData $InputData -Target $target -Context $context)
        Write-Host ('Direct memberships including primary: '+$context.Groups.Count)
        $context.Groups | Group-Object Scope | Select-Object Name,Count | Format-Table -AutoSize | Out-Host
        $context.Mappings | Select-Object SourceName,Status,TargetDN | Format-Table -Wrap | Out-Host
        Set-UserMigrationStage $context 'ChildObjects'
        $descendants=@(Get-ADObject -SearchBase $user.DistinguishedName -SearchScope Subtree -LDAPFilter '(objectClass=*)' -Server $source.RIDMaster -Properties * | Where-Object { $_.ObjectGUID -ne $user.ObjectGUID })
        Invoke-ADMigrationMeasuredRead $context 'Children.Export' { Export-ADMigrationSnapshot -Objects $descendants -Path (Join-Path $directory 'ChildSnapshots.clixml') }
        $context.Children=@(foreach ($child in $descendants) {
            $allowed=@($InputData.Config.ApprovedChildObjectClasses) -contains [string]$child.ObjectClass
            [pscustomobject]@{ GUID=$child.ObjectGUID.ToString(); DN=$child.DistinguishedName; Class=[string]$child.ObjectClass; Allowlisted=$allowed; Action='ReviewOnly'; Protected=(Get-ADMigrationOptionalProperty $child 'ProtectedFromAccidentalDeletion') }
        })
        foreach ($child in $context.Children) {
            Add-UserMigrationFinding $context 'ChildObject' 'Blocker' ($child.Class+': '+$child.DN+'. Allowlisted='+$child.Allowlisted+'. No deletion authorized or implemented; full subtree requires review.')
        }
        if (-not $context.Children.Count) { Add-UserMigrationFinding $context 'ChildObjects' 'Pass' 'No visible descendants returned. Directory ACL visibility must still be considered.' }
        $cleanup=@(Get-ADMigrationChildCleanupPlan -Children $context.Children)
        Write-ADMigrationJson ([ordered]@{ExecutionAvailable=$false;Policy='ActiveSync cleanup is mandatory before any user move. Unknown descendants block automatic cleanup. Fresh subtree validation required.';Objects=$cleanup}) (Join-Path $directory 'ChildCleanupPlan.json')
        Export-ADMigrationCsv -Rows $cleanup -Path (Join-Path $directory 'ChildCleanupPlan.csv') -Columns @('GUID','DN','Class','RequiredBeforeMove','Disposition','ExecutionAvailable')
        if (@($cleanup | Where-Object RequiredBeforeMove).Count) {
            Add-UserMigrationFinding $context 'ActiveSyncCleanupRequired' 'Blocker' 'ActiveSync objects must be removed before migration. Cleanup plan generated; no objects deleted. Unknown descendants require separate review.'
        }
        Set-UserMigrationStage $context 'GroupCatalog'
        try { Invoke-ADMigrationGroupCatalog -Domains @($source,$target) -DirectGroups $context.Groups -Context $context -Config $InputData.Config }
        catch {
            Write-ADMigrationJson ([ordered]@{Status='Incomplete';Error=$_.Exception.Message;ChangesPerformed=$false;ApprovedMappings=0;Note='Any catalog files present are partial evidence, not a complete assessment.'}) (Join-Path $directory 'GroupCatalogSummary.json')
            Add-UserMigrationFinding $context 'GroupCatalogIncomplete' 'Blocker' $_.Exception.Message
        }
        Set-UserMigrationStage $context 'SourceConsistency'
        $after = Get-ADUser -Identity $sourceReadGuid -Server $sourceReadServer -Properties uSNChanged,whenChanged
        $finalUSN=Get-ADMigrationUSNObservation -Value $after.uSNChanged -Server $sourceReadServer -ObjectGUID $after.ObjectGUID -Label 'FinalGetADUser'
        $consistency=Compare-ADMigrationUSNObservations -Observations @($initialUSN,$rawUSN,$finalUSN)
        Write-ADMigrationJson $consistency (Join-Path $directory 'SourceConsistency.json')
        if ($consistency.Status -eq 'Changed') {
            Add-UserMigrationFinding $context 'SourceChangedDuringAudit' 'Blocker' ('USN values differ on '+$sourceReadServer+': '+(($consistency.Observations | ForEach-Object CanonicalValue) -join ' -> ')+'. See SourceConsistency.json; rerun after investigating changes.')
        } elseif ($consistency.Status -eq 'Invalid') {
            Add-UserMigrationFinding $context 'SourceConsistencyInvalid' 'Blocker' 'Could not compare valid scalar USNs for the same GUID and DC. See SourceConsistency.json.'
        } else { Add-UserMigrationFinding $context 'SourceConsistency' 'Pass' ('Same GUID/DC and normalized Int64 USN across all three observations: '+$finalUSN.CanonicalValue+'. This is not a transactional snapshot of group memberships.') }
        Add-UserMigrationFinding $context 'ManualRunbookTasks' 'Review' 'Confirm change approval, application dependencies, home-drive plan, application validation and temporary administrator access cleanup.'
        Add-UserMigrationFinding $context 'RealExecutionDisabled' 'Review' 'This audit entry point performs no migration. Use the separate execution-preview workflow after reviewing this evidence.'
    } catch {
        Add-UserMigrationFinding $context 'AssessmentIncomplete' 'Blocker' ($context.State.Stage+': '+$_.Exception.Message)
    } finally {
        Export-ADMigrationReports -Context $context -InputData $InputData
    }
    [pscustomobject]@{ Status=$context.State.Status; Directory=$directory }
}
Export-ModuleMember -Function Invoke-ADMigrationExecution,New-UserMigrationExecutionPreview,Invoke-ADMigrationActiveSyncCleanup,Read-ADMigrationInput,Invoke-ADMigrationAudit,ConvertTo-ADMigrationLdapValue,Get-ADMigrationMappingAnalysis,Write-ADMigrationSection,Assert-ADMigrationSecurityPreflight,Test-ADMigrationProcessElevated,Start-ADMigrationElevatedAudit
