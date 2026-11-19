#Requires -Version 5.1
<#
.SYNOPSIS
    Tests the real mapping analyzer using fictional directory responses only.
.NOTES
    Author: Joel Cottrell | Version 1.0.13
    This does not test a real account move or contact Active Directory.
#>
[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$module=@(Import-Module (Join-Path $root 'Modules/ADMigration.ADUserMigration.psm1') -Force -PassThru)
if ($module.Count -ne 1) { throw 'Expected exactly one imported module.' }
$m=$module[0]
$temp=Join-Path ([IO.Path]::GetTempPath()) ('ADMigrationFixture-'+[guid]::NewGuid())
[void](New-Item -ItemType Directory -Path $temp)
try {
    foreach ($file in Get-ChildItem (Join-Path $PSScriptRoot 'Fixtures') -Filter '*.json') {
        $f=Get-Content -LiteralPath $file.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
        if (-not $f.Synthetic) { throw 'Only synthetic fixtures allowed.' }
        & $m { param($targets)
            $script:ADMigrationFixtureTargets=$targets
            function script:Get-ADGroup {
                param($Identity,$Server,$LDAPFilter,$SearchBase)
                if ($LDAPFilter) { return }
                $found=@($script:ADMigrationFixtureTargets | Where-Object SID -eq $Identity)
                if ($found.Count -ne 1) { throw 'Synthetic target not found.' }
                $found[0]
            }
        } $f.TargetGroups
        $ctx=[pscustomobject]@{Findings=(New-Object 'System.Collections.Generic.List[object]');LogPath=(Join-Path $temp 'test.jsonl');State=[pscustomobject]@{SourceGUID='00000000-0000-0000-0000-000000000001'}}
        $inputData=[pscustomobject]@{Maps=$f.Maps;Row=[pscustomobject]@{MigrationDirection='FIXTURE';ChangeReference='TEST-1'}}
        $actual=@(Get-ADMigrationMappingAnalysis $f.Groups $inputData $f.Target $ctx)
        if ($actual.Count -ne $f.ExpectedStatuses.Count) { throw 'Result count mismatch.' }
        for($i=0;$i -lt $actual.Count;$i++) { if($actual[$i].Status -ne $f.ExpectedStatuses[$i]) { throw ('Unexpected result at index '+$i) } }
        Write-Host ('PASS: '+$file.BaseName+' '+$actual.Count+' membership decisions')
        $mapped=@($f.Groups | Where-Object { $_.SID -in @($f.Maps | Where-Object Action -eq 'Map' | ForEach-Object SourceGroupSID) })
        if($mapped.Count -gt 0) {
            & $m { $script:ADMigrationFixtureTargets=@() }
            $missing=@(Get-ADMigrationMappingAnalysis $mapped $inputData $f.Target $ctx)
            if(@($missing | Where-Object Status -ne 'MappingInvalid').Count) { throw 'Missing targets did not fail closed.' }
            Write-Host 'PASS: Missing mapped targets fail closed, including universal-source mappings'
        }
    }
} finally {
    Remove-Module $m -Force
    Remove-Item -LiteralPath $temp -Recurse -Force
}
