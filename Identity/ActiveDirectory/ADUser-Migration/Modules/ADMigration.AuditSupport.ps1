#Requires -Version 5.1
<#
.SYNOPSIS
    Read-only classification, consistency evidence and group catalog helpers.
.NOTES
    Author: Joel Cottrell
    Version: 1.0.13 | 2026-11-12
#>
function Test-ADMigrationRetentionScope {
    param($Group,[string]$TargetDomain)
    # Eligibility is not approval and does not prove application access.
    ($Group.Scope -in @('Universal','DomainLocal')) -or
        ($Group.Scope -eq 'Global' -and $Group.Domain -eq $TargetDomain)
}
function Get-ADMigrationUSNObservation {
    param([AllowNull()]$Value,[string]$Server,[guid]$ObjectGUID,[string]$Label)
    $type=if ($null -eq $Value) { 'null' } else { $Value.GetType().FullName }
    $values=@($Value | ForEach-Object { $_ })
    $texts=@($values | ForEach-Object { [string]$_ })
    $types=@($values | ForEach-Object { if ($null -eq $_) { 'null' } else { $_.GetType().FullName } })
    $number=[int64]0
    $valid=$values.Count -eq 1 -and $texts[0] -match '^\d+$'
    if ($valid) { $valid=[int64]::TryParse($texts[0],[Globalization.NumberStyles]::None,[Globalization.CultureInfo]::InvariantCulture,[ref]$number) }
    [pscustomobject]@{Label=$Label;CapturedUtc=[datetime]::UtcNow.ToString('o');Server=$Server;ObjectGUID=$ObjectGUID.ToString()
        ContainerType=$type;ElementTypes=$types;RawValues=$texts;Count=$values.Count;Valid=[bool]$valid
        CanonicalValue=$(if ($valid) { $number.ToString([Globalization.CultureInfo]::InvariantCulture) } else { $null })}
}
function Compare-ADMigrationUSNObservations {
    param([object[]]$Observations)
    $status='Invalid'
    if ($Observations.Count -ge 2 -and @($Observations | Where-Object { -not $_.Valid }).Count -eq 0 -and
        @($Observations.Server | Sort-Object -Unique).Count -eq 1 -and
        @($Observations.ObjectGUID | Sort-Object -Unique).Count -eq 1) {
        $status=if (@($Observations.CanonicalValue | Sort-Object -Unique).Count -eq 1) { 'Unchanged' } else { 'Changed' }
    }
    [pscustomobject]@{Status=$status;Observations=$Observations;Limitations='Same-object USN only. Group links on other objects, replication convergence and a transactional directory snapshot are not proven.'}
}
function Get-ADMigrationChildCleanupPlan {
    param([object[]]$Children)
    foreach ($child in $Children) {
        $activeSync=$child.Class -in @('msExchActiveSyncDevices','msExchActiveSyncDevice')
        [pscustomobject]@{GUID=$child.GUID;DN=$child.DN;Class=$child.Class;RequiredBeforeMove=$activeSync
            Disposition=$(if ($activeSync) { 'MandatoryActiveSyncCleanup' } else { 'UnknownClassReviewBlocksCleanup' });ExecutionAvailable=$false}
    }
}
function Export-ADMigrationCsv {
    param([object[]]$Rows,[string]$Path,[string[]]$Columns)
    if ($Rows.Count) { $Rows | Select-Object $Columns | Export-Csv -LiteralPath $Path -NoTypeInformation -Encoding UTF8 }
    else { ('"'+($Columns -join '","')+'"') | Set-Content -LiteralPath $Path -Encoding UTF8 }
}
function Get-ADMigrationMatchKey {
    param([AllowEmptyString()][string]$Name,[string]$TrailingSuffix)
    # Preserve all other tokens, including Prod/Test/Train/Admin and numbers.
    $n=$Name.Trim().ToLowerInvariant()
    if ($TrailingSuffix) { $n = $n -replace ('[ _-]+'+[regex]::Escape($TrailingSuffix)+'$'),'' }
    ($n -replace '[\s_-]+',' ').Trim()
}
function Get-ADMigrationCatalogCandidates {
    param([object[]]$Groups,[int]$MaxPairs=20000,[string]$TrailingSuffix)
    $index=@{}; $pairs=@{}
    foreach ($g in $Groups) {
        $keys=@(@($g.Name,$g.SamAccountName,$g.DisplayName) | ForEach-Object { Get-ADMigrationMatchKey ([string]$_) -TrailingSuffix $TrailingSuffix } | Where-Object { $_ } | Sort-Object -Unique)
        foreach ($key in $keys) {
            if (-not $index.ContainsKey($key)) { $index[$key]=New-Object 'System.Collections.Generic.List[object]' }
            $index[$key].Add($g)
        }
    }
    foreach ($key in @($index.Keys | Sort-Object)) {
        $bucket=@($index[$key] | Sort-Object SID -Unique)
        for ($i=0; $i -lt $bucket.Count; $i++) {
            for ($j=$i+1; $j -lt $bucket.Count; $j++) {
                $a=$bucket[$i]; $b=$bucket[$j]
                if ($a.SID -eq $b.SID -or (-not $a.IsSeed -and -not $b.IsSeed)) { continue }
                $pair=$a.SID+'|'+$b.SID
                if ($pairs.ContainsKey($pair)) { continue }
                if ($pairs.Count -ge $MaxPairs) { throw "Candidate pair limit $MaxPairs exceeded. No complete candidate report was produced." }
                $shared=@($a.ParentSIDs | Where-Object { $b.ParentSIDs -contains $_ })
                $status=if ($a.Category -ne $b.Category) { 'CategoryMismatchReview' } else { 'PossibleMatch' }
                $pairs[$pair]=[pscustomobject]@{LeftName=$a.Name;LeftSID=$a.SID;LeftDomain=$a.Domain;LeftScope=$a.Scope
                    RightName=$b.Name;RightSID=$b.SID;RightDomain=$b.Domain;RightScope=$b.Scope;MatchKey=$key
                    SharedDirectParentSIDs=($shared -join ';');Status=$status;Approved=$false
                    Evidence='Normalized Name/SAM/DisplayName equality. Same-parent nesting is supporting evidence only; application equivalence is NOT established.'}
            }
        }
    }
    $counts=@{}
    foreach ($p in $pairs.Values) { foreach ($sid in @($p.LeftSID,$p.RightSID)) { if (-not $counts.ContainsKey($sid)) { $counts[$sid]=0 }; $counts[$sid]++ } }
    foreach ($p in @($pairs.Values | Sort-Object LeftName,RightName)) {
        if ($p.Status -eq 'PossibleMatch' -and ($counts[$p.LeftSID] -gt 1 -or $counts[$p.RightSID] -gt 1)) { $p.Status='AmbiguousMatch' }
        $p
    }
}
function Invoke-ADMigrationGroupCatalog {
    param($Domains,[object[]]$DirectGroups,$Context,$Config)
    $settings=Get-ADMigrationOptionalProperty $Config 'GroupCatalog'
    if ($null -eq $settings) { throw 'GroupCatalog configuration is required in v1.0.13. Use the supplied config.' }
    $suffix=[string](Get-ADMigrationOptionalProperty $settings 'TrailingNameSuffix')
    if ($suffix -and $suffix -notmatch '^[A-Za-z0-9]+$') { throw 'TrailingNameSuffix must be a literal alphanumeric token.' }
    $prefixes=@($settings.Prefixes)
    if (-not $prefixes.Count -or @($prefixes | Where-Object { $_ -notmatch '^[A-Za-z0-9]+$' }).Count) { throw 'Catalog Prefixes must be nonempty literal alphanumeric prefixes.' }
    foreach ($key in @('MaxInventoryGroups','MaxSelectedGroups','MaxCandidatePairs')) {
        if ($settings.$key -notmatch '^\d+$' -or [int64]$settings.$key -lt 1 -or [int64]$settings.$key -gt 100000) { throw "Invalid catalog limit: $key" }
    }
    $nodes=@{}; $byDN=@{}; $directSIDs=@($DirectGroups | ForEach-Object SID)
    $started=[datetime]::UtcNow.ToString('o')
    # One bounded, paged forward-membership inventory per domain. We keep group
    # links only in output, never an organization-wide user membership dump.
    foreach ($domain in @($Domains | Sort-Object DNSRoot -Unique)) {
        Add-UserMigrationFinding $Context 'GroupCatalog.Query.Start' 'Info' ('Reading group metadata/nesting from '+$domain.DNSRoot+' on '+$domain.RIDMaster+'. This can take longer than the user snapshot.')
        Get-ADGroup -Filter * -SearchBase $domain.DistinguishedName -Server $domain.RIDMaster -Properties DisplayName,Description,ManagedBy,member -ResultPageSize 500 -ErrorAction Stop | ForEach-Object {
            $g=$_; $sid=$g.SID.Value
            if ($nodes.Count -ge [int]$settings.MaxInventoryGroups -and -not $nodes.ContainsKey($sid)) { throw 'Catalog inventory limit exceeded; increase reviewed limit or narrow scope in a future release.' }
            $names=@([string]$g.Name,[string]$g.SamAccountName,[string]$g.DisplayName)
            $familyMatch=$false
            foreach ($prefix in $prefixes) { foreach ($name in $names) { if ($name.StartsWith($prefix,[StringComparison]::OrdinalIgnoreCase)) { $familyMatch=$true } } }
            $node=[pscustomobject]@{Name=$g.Name;SamAccountName=$g.SamAccountName;DisplayName=$g.DisplayName
                SID=$sid;ObjectGUID=$g.ObjectGUID.ToString();DN=$g.DistinguishedName;Domain=$domain.DNSRoot
                Scope=[string]$g.GroupScope;Category=[string]$g.GroupCategory;Description=$g.Description;ManagedBy=$g.ManagedBy
                IsSeed=($familyMatch -or $directSIDs -contains $sid);SeedReason=$(if ($familyMatch) { 'ApplicationPrefix' } elseif ($directSIDs -contains $sid) { 'PilotDirectMembership' } else { 'Nesting' })
                MemberDNs=@($g.member);ParentSIDs=@();ChildSIDs=@()}
            $nodes[$sid]=$node; $byDN[$g.DistinguishedName]=$sid
        }
        Add-UserMigrationFinding $Context 'GroupCatalog.Query.Complete' 'Info' ('Finished '+$domain.DNSRoot+'; cumulative groups='+$nodes.Count)
    }
    # Resolve group FSP representations within the two domains as well.
    $fspAliases=@{}
    foreach ($domain in $Domains) {
        foreach ($fsp in @(Get-ADObject -LDAPFilter '(objectClass=foreignSecurityPrincipal)' -SearchBase $domain.DistinguishedName -Server $domain.RIDMaster -Properties objectSid -ErrorAction Stop)) {
            $sid=[string]$fsp.objectSid
            if ($nodes.ContainsKey($sid)) { $fspAliases[$fsp.DistinguishedName]=$sid }
        }
    }
    $edges=New-Object 'System.Collections.Generic.List[object]'
    foreach ($parent in $nodes.Values) {
        foreach ($dn in $parent.MemberDNs) {
            $sid=$null; $via='DirectDN'
            if ($byDN.ContainsKey($dn)) { $sid=$byDN[$dn] }
            elseif ($fspAliases.ContainsKey($dn)) { $sid=$fspAliases[$dn];$via='ForeignSecurityPrincipal' }
            if ($sid) {
                $parent.ChildSIDs+= $sid; $nodes[$sid].ParentSIDs+= $parent.SID
                $edges.Add([pscustomobject]@{ChildSID=$sid;ParentSID=$parent.SID;ChildName=$nodes[$sid].Name;ParentName=$parent.Name;Via=$via})
            }
        }
        $parent.MemberDNs=@()
    }
    # Walk connected group components in both directions, with cycle protection.
    $selected=@{}; $queue=New-Object 'System.Collections.Generic.Queue[string]'
    foreach ($n in @($nodes.Values | Where-Object IsSeed | Sort-Object SID)) { $queue.Enqueue($n.SID) }
    while ($queue.Count) {
        $sid=$queue.Dequeue()
        if ($selected.ContainsKey($sid)) { continue }
        if ($selected.Count -ge [int]$settings.MaxSelectedGroups) { throw 'Selected nesting component limit exceeded. Catalog is incomplete; no match approval is possible.' }
        $selected[$sid]=$nodes[$sid]
        foreach ($related in @($nodes[$sid].ParentSIDs)+@($nodes[$sid].ChildSIDs)) { if (-not $selected.ContainsKey($related)) { $queue.Enqueue($related) } }
    }
    $catalog=@($selected.Values | Sort-Object Domain,Name)
    $selectedEdges=@($edges | Where-Object { $selected.ContainsKey($_.ChildSID) -and $selected.ContainsKey($_.ParentSID) })
    $export=@(foreach ($n in $catalog) {
        [pscustomobject]@{Name=$n.Name;SamAccountName=$n.SamAccountName;DisplayName=$n.DisplayName;SID=$n.SID;ObjectGUID=$n.ObjectGUID;DN=$n.DN
            Domain=$n.Domain;Scope=$n.Scope;Category=$n.Category;Description=$n.Description;ManagedBy=$n.ManagedBy;SeedReason=$n.SeedReason
            ParentSIDs=($n.ParentSIDs -join ';');ChildSIDs=($n.ChildSIDs -join ';')}
    })
    Export-ADMigrationCsv $export (Join-Path $Context.Directory 'GroupCatalog.csv') @('Name','SamAccountName','DisplayName','SID','ObjectGUID','DN','Domain','Scope','Category','Description','ManagedBy','SeedReason','ParentSIDs','ChildSIDs')
    Export-ADMigrationCsv $selectedEdges (Join-Path $Context.Directory 'GroupNesting.csv') @('ChildSID','ParentSID','ChildName','ParentName','Via')
    $candidates=@(Get-ADMigrationCatalogCandidates -Groups $catalog -MaxPairs ([int]$settings.MaxCandidatePairs) -TrailingSuffix $suffix)
    Export-ADMigrationCsv $candidates (Join-Path $Context.Directory 'GroupMatchCandidates.csv') @('LeftName','LeftSID','LeftDomain','LeftScope','RightName','RightSID','RightDomain','RightScope','MatchKey','SharedDirectParentSIDs','Status','Approved','Evidence')
    $reviews=@(foreach ($g in @($catalog | Where-Object IsSeed)) {
        $matches=@($candidates | Where-Object { $_.LeftSID -eq $g.SID -or $_.RightSID -eq $g.SID })
        [pscustomobject]@{Name=$g.Name;SID=$g.SID;Domain=$g.Domain;Scope=$g.Scope;CandidateCount=$matches.Count
            Status=$(if ($matches.Count -eq 0) { 'NoNameEquivalentFound' } elseif ($matches.Count -gt 1) { 'AmbiguousMatch' } else { 'PossibleMatchReview' })
            Note='Catalog name matching only. Consult user GroupMappingAnalysis for same-group retention. No candidate means no normalized-name match, not proof that no functional equivalent exists.'}
    })
    Export-ADMigrationCsv $reviews (Join-Path $Context.Directory 'GroupCatalogReview.csv') @('Name','SID','Domain','Scope','CandidateCount','Status','Note')
    $metadata=[ordered]@{Status='CollectedWithinDeclaredScope';StartedUtc=$started;CompletedUtc=[datetime]::UtcNow.ToString('o')
        Domains=@($Domains | Select-Object DNSRoot,RIDMaster);Prefixes=$prefixes;TrailingNameSuffix=$suffix;InventoryCount=$nodes.Count;SelectedCount=$catalog.Count
        NestingEdges=$selectedEdges.Count;CandidatePairs=$candidates.Count;ApprovedMappings=0;ChangesPerformed=$false
        Limitations=@('Two-domain group graph only; outside-domain groups and their nesting are not traversed.','Primary-group relationships and inaccessible objects are not proven by this catalog.','Forward member links are read; only links resolving to inventoried groups are exported.','No application ACL, provisioning, or resource access equivalence is proven.','Catalog is not transactional and does not authorize renames or membership changes.')}
    Write-ADMigrationJson $metadata (Join-Path $Context.Directory 'GroupCatalogSummary.json')
    Add-UserMigrationFinding $Context 'GroupCatalog' 'Review' ('Catalog collected: '+$catalog.Count+' groups, '+$selectedEdges.Count+' nesting edges, '+$candidates.Count+' candidate pairs. No matches approved. See GroupCatalogSummary.json for scope limitations.')
}
