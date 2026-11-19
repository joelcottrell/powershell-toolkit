# Author: Joel Cottrell | Version: 1.0.13
# Deliberately separate from the read-only migration audit entry point.
function Get-ADMigrationCleanupOperator {
    $identity=[Security.Principal.WindowsIdentity]::GetCurrent()
    try { [pscustomobject]@{Name=$identity.Name;SID=$identity.User.Value} } finally { $identity.Dispose() }
}
function Get-ADMigrationCleanupInventory {
    param($User,[string]$Server)
    @(Get-ADObject -SearchBase $User.DistinguishedName -SearchScope Subtree -Filter * -Server $Server -Properties * -ErrorAction Stop | Where-Object { [string]$_.ObjectGUID -ne [string]$User.ObjectGUID })
}
function ConvertTo-ADMigrationCleanupItems {
    param([object[]]$Objects)
    @($Objects | ForEach-Object {
        if ([string]$_.ObjectClass -notin @('msExchActiveSyncDevices','msExchActiveSyncDevice')) { throw ('Unknown child class blocks cleanup: '+$_.ObjectClass) }
        if ($_.ProtectedFromAccidentalDeletion -ne $false) { throw 'Protected or unreadable deletion-protection state blocks cleanup.' }
        $usn=[string]$_.uSNChanged
        if ($usn -notmatch '^\d+$') { throw 'Missing child USN blocks cleanup.' }
        [pscustomobject]@{GUID=([guid]$_.ObjectGUID).ToString();DN=[string]$_.DistinguishedName;Class=[string]$_.ObjectClass;USN=$usn}
    } | Sort-Object GUID)
}
function Assert-ADMigrationCleanupItemsEqual {
    param([object[]]$Expected,[object[]]$Actual)
    $expectedItems=@($Expected); $actualItems=@($Actual)
    if ($expectedItems.Count -ne $actualItems.Count) { throw ('Child inventory count changed: preview={0}, live={1}. Create a new preview.' -f $expectedItems.Count,$actualItems.Count) }
    $seen=@{}
    foreach ($item in $expectedItems) {
        $guid=([guid]$item.GUID).ToString()
        if ($seen.ContainsKey($guid)) { throw 'Duplicate child GUID in preview.' }
        $seen[$guid]=$true
        $match=@($actualItems | Where-Object { [string]$_.GUID -eq $guid })
        if ($match.Count -ne 1) { throw ('Child inventory identity changed for GUID '+$guid+'. Create a new preview.') }
        foreach ($field in @('DN','Class','USN')) {
            if ([string]$item.$field -cne [string]$match[0].$field) { throw ('Child inventory changed for GUID '+$guid+', field '+$field+'. Stop and create a new preview.') }
        }
    }
}
function Invoke-ADMigrationActiveSyncCleanup {
    [CmdletBinding(SupportsShouldProcess=$true,ConfirmImpact='High')]
    param($InputData,[guid]$ExpectedUserGUID,[string]$OutputRoot,[string]$PlanPath,[switch]$Execute)
    Assert-ADMigrationSecurityPreflight -ForestRoot $InputData.Config.ForestRoot
    $domain=Get-ADDomain -Identity $InputData.Direction.SourceDomain -Server $InputData.Direction.SourceDomain -ErrorAction Stop
    $server=[string]$domain.RIDMaster
    $dc=Get-ADDomainController -Identity $server -Server $domain.DNSRoot -ErrorAction Stop
    if ($dc.IsReadOnly -or $dc.Domain -ne $domain.DNSRoot) { throw 'Source RID Master must be writable and in the source domain.' }
    $user=Get-ADUser -Identity $ExpectedUserGUID -Server $server -Properties * -ErrorAction Stop
    if ($user.SamAccountName -ne $InputData.Row.SamAccountName -or $user.SID.AccountDomainSid.Value -ne $domain.DomainSID.Value) { throw 'User GUID/account/domain mismatch.' }
    if ($user.adminCount -eq 1 -or $user.ProtectedFromAccidentalDeletion) { throw 'Privileged or deletion-protected user requires separate review.' }
    $operator=Get-ADMigrationCleanupOperator
    $operatorName=$operator.Name; $operatorSID=$operator.SID
    if ($user.SID.Value -eq $operatorSID) { throw 'Cannot clean up the operator account.' }
    # A machine-wide exclusive handle serializes this tool for this user on this host.
    # It is not a distributed AD lock; coordinate across administration hosts.
    $mutex=New-Object Threading.Mutex($false,('Global\ADMigrationActiveSync-'+$ExpectedUserGUID.ToString()))
    $held=$false; $directory=$null; $state=$null
    try {
        try { $held=$mutex.WaitOne(0) } catch [Threading.AbandonedMutexException] { $held=$true }
        if (-not $held) { throw 'Another cleanup is active for this user on this computer.' }
        $objects=@(Get-ADMigrationCleanupInventory $user $server)
        $items=@(ConvertTo-ADMigrationCleanupItems $objects)
        $items | Format-Table GUID,Class,DN -AutoSize | Out-Host
        if ($Execute) {
            if (-not $PlanPath) { throw 'Execute requires the saved PreviewPlan.json.' }
            $plan=Get-Content -LiteralPath $PlanPath -Raw -Encoding UTF8 | ConvertFrom-Json
            if ($plan.Version -ne '1.0.13' -or $plan.Mode -ne 'ActiveSyncCleanupPreview' -or [string]$plan.UserGUID -ne $ExpectedUserGUID.ToString() -or $plan.UserDN -ne $user.DistinguishedName -or $plan.Server -ne $server -or $plan.CsvHash -ne $InputData.CsvHash -or $plan.MapHash -ne $InputData.MapHash -or $plan.ConfigHash -ne $InputData.ConfigHash) { throw 'Preview does not match this user, input, configuration or RID Master.' }
            $age=[datetime]::UtcNow - ([datetime]$plan.CreatedUtc).ToUniversalTime()
            if ($age.TotalHours -gt 24 -or $age.TotalSeconds -lt 0) { throw 'Preview expired or future dated. Create a fresh preview.' }
            Assert-ADMigrationCleanupItemsEqual @($plan.Items) $items
        }
        if ($WhatIfPreference) {
            [void]$PSCmdlet.ShouldProcess($user.DistinguishedName,('Delete '+$items.Count+' individually validated ActiveSync child objects'))
            return [pscustomobject]@{Status='WhatIf';Directory=$null}
        }
        $directory=Join-Path $OutputRoot ('Cleanup-'+[datetime]::UtcNow.ToString('yyyyMMddTHHmmssfffZ')+'-'+[guid]::NewGuid().ToString('N').Substring(0,8))
        [void][IO.Directory]::CreateDirectory($directory); Protect-ADMigrationDirectory $directory
        Export-ADMigrationSnapshot @($user) (Join-Path $directory 'BeforeUser.clixml')
        Export-ADMigrationSnapshot $objects (Join-Path $directory 'BeforeChildren.clixml')
        $state=[ordered]@{Version='1.0.13';Status='Preview';UserGUID=$ExpectedUserGUID.ToString();UserDN=$user.DistinguishedName;Server=$server;Operator=$operatorName;ChangeReference=$InputData.Row.ChangeReference;CompletedGUIDs=@();PendingGUID=$null;Error=$null;AccountMoved=$false;UpdatedUtc=[datetime]::UtcNow.ToString('o')}
        Write-ADMigrationJson $state (Join-Path $directory 'CleanupState.json')
        if (-not $Execute) {
            $plan=[ordered]@{Version='1.0.13';Mode='ActiveSyncCleanupPreview';CreatedUtc=[datetime]::UtcNow.ToString('o');UserGUID=$ExpectedUserGUID.ToString();UserDN=$user.DistinguishedName;Server=$server;CsvHash=$InputData.CsvHash;MapHash=$InputData.MapHash;ConfigHash=$InputData.ConfigHash;Items=$items}
            Write-ADMigrationJson $plan (Join-Path $directory 'PreviewPlan.json')
            return [pscustomobject]@{Status='PreviewOnly';Directory=$directory}
        }
        if ($items.Count -eq 0) { $state.Status='AlreadyClear' }
        else {
            if (-not $PSCmdlet.ShouldProcess($user.DistinguishedName,('Permanently remove '+$items.Count+' ActiveSync child objects; no account move'))) { $state.Status='Cancelled'; return [pscustomobject]@{Status='Cancelled';Directory=$directory} }
            $phrase='CLEANUP '+$InputData.Row.SamAccountName
            if ((Read-Host ('Type exactly '+$phrase+' to delete the displayed ActiveSync objects')) -cne $phrase) { $state.Status='Cancelled'; return [pscustomobject]@{Status='Cancelled';Directory=$directory} }
            Assert-ADMigrationSecurityPreflight -ForestRoot $InputData.Config.ForestRoot
            $remaining=@($items)
            # Longest DN first ensures descendants are removed before parents, including escaped commas.
            foreach ($item in @($items | Sort-Object @{Expression={$_.DN.Length};Descending=$true})) {
                $currentUser=Get-ADUser -Identity $ExpectedUserGUID -Server $server -Properties ProtectedFromAccidentalDeletion -ErrorAction Stop
                if ($currentUser.DistinguishedName -ne $user.DistinguishedName -or $currentUser.ProtectedFromAccidentalDeletion) { throw 'User moved or became protected. Cleanup stopped.' }
                $live=@(ConvertTo-ADMigrationCleanupItems @(Get-ADMigrationCleanupInventory $currentUser $server))
                Assert-ADMigrationCleanupItemsEqual $remaining $live
                $leaf=@(Get-ADObject -SearchBase $item.DN -SearchScope OneLevel -Filter * -Server $server -ErrorAction Stop)
                if ($leaf.Count) { throw 'Object still has children. Non-recursive cleanup stopped.' }
                $state.Status='Executing';$state.PendingGUID=$item.GUID
                Write-ADMigrationJson $state (Join-Path $directory 'CleanupState.json')
                # No -Recursive, no protection override, no user deletion.
                Remove-ADObject -Identity ([guid]$item.GUID) -Server $server -Confirm:$false -ErrorAction Stop
                $state.CompletedGUIDs+=@($item.GUID);$state.PendingGUID=$null
                Write-ADMigrationJson $state (Join-Path $directory 'CleanupState.json')
                $remaining=@($remaining | Where-Object GUID -ne $item.GUID)
                $after=@(ConvertTo-ADMigrationCleanupItems @(Get-ADMigrationCleanupInventory $currentUser $server))
                Assert-ADMigrationCleanupItemsEqual $remaining $after
            }
            $state.Status='CleanupVerifiedOnSourceRID'
        }
        $finalUser=Get-ADUser -Identity $ExpectedUserGUID -Server $server -Properties * -ErrorAction Stop
        if ($finalUser.DistinguishedName -ne $user.DistinguishedName) { throw 'Final user location changed.' }
        $final=@(Get-ADMigrationCleanupInventory $finalUser $server)
        if ($final.Count) { throw 'Children remain or were recreated. Cleanup is not complete.' }
        Export-ADMigrationSnapshot @($finalUser) (Join-Path $directory 'AfterUser.clixml')
        Write-ADMigrationJson ([ordered]@{VerifiedUtc=[datetime]::UtcNow.ToString('o');Server=$server;RemainingChildren=0;AccountMoved=$false;MigrationReady=$false;Next='Run a fresh read-only migration audit. Replication and device re-creation still require review.'}) (Join-Path $directory 'CleanupVerification.json')
        return [pscustomobject]@{Status=$state.Status;Directory=$directory}
    } catch {
        if ($state) { $state.Status='FailedOrPartial';$state.Error=$_.Exception.Message }
        throw
    } finally {
        if ($state -and $directory) { $state.UpdatedUtc=[datetime]::UtcNow.ToString('o');Write-ADMigrationJson $state (Join-Path $directory 'CleanupState.json');Write-Host ('Cleanup evidence: '+$directory) }
        if ($held) { $mutex.ReleaseMutex() };$mutex.Dispose()
    }
}
