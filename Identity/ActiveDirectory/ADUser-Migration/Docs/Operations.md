# Operations and recovery

## Review and execution

Review the CSV request, snapshot, user identity, target OU and action plan. The CLI discovers writable RID Masters and verifies source and target identity, direct groups, protected accounts and child objects. It records a source consistency check based on GUID, DC and USN.

Execution removes approved source non-primary global memberships before moving the user exactly once. It verifies source absence, target identity and SID history, then adds and verifies every replacement membership before removing mapped universal or domain-local source links. Retained groups and the final direct and primary group set are verified separately. The password timestamp check permits the documented transformation of a nonzero pwdLastSet during a cross-domain move. Actual password sign-in remains a manual check.

The audit and move entry points skip AD access and file writes with -WhatIf. Normal previews, -DryRun and -TestMode make live read-only AD queries and write evidence. ActiveSync cleanup -WhatIf also reads live directory state. Use the offline suites for directory-free testing.

## ActiveSync children

The migration blocks if it finds child objects. Use the GUID from the audit as $userGuid and generate a separate cleanup preview. Unknown, protected or changed descendants block cleanup.

~~~powershell
.\Remove-ADUserActiveSyncChild.ps1 -CsvPath .\Examples\Migration.csv -ExpectedUserGUID $userGuid
~~~

Review PreviewPlan.json, set $cleanupPlanPath to that exact path and run the following with an approved change. The script requires typed CLEANUP followed by the sAMAccountName, refreshes preflight and revalidates the inventory during deletion. Cleanup snapshots are evidence. Generate a fresh migration preview afterward.

~~~powershell
.\Remove-ADUserActiveSyncChild.ps1 -CsvPath .\Examples\Migration.csv -ExpectedUserGUID $userGuid -Execute -PlanPath $cleanupPlanPath -Confirm
~~~

## Recovery and evidence

On failure, preserve the original plan, state, execution registry and evidence. Use the same execution host and output root throughout. Local locks and an exclusive registry record guard against repeats on that host and output root. Coordinate any run elsewhere.

Resume is limited to reconciling an already attempted move with the GUID conclusively visible only in the target domain. Set $planPath to the original execution plan. Source-only, duplicate or unknown identity requires manual investigation. Pre-move membership removals require journal-based review and manual recovery. Keep existing operational runs with the package that created them.

~~~powershell
.\Move-ADUserAccount.ps1 -CsvPath .\Examples\Migration.csv -Execute -Resume -PlanPath $planPath -Confirm
~~~

Store the local JSON, CSV, HTML, CLIXML and logs privately. They can contain identifiable directory data. A result of ADVerifiedManualChecksPending calls for sign-in, application, home-drive and change follow-up plus removal of any temporary administrator access under the approved procedure.
