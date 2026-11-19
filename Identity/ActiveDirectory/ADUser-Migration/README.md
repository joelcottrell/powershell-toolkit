# Active Directory User Migration Tool

Version 1.0.13 is a Windows PowerShell CLI for moving one user at a time between a forest root domain and its direct child domain. The audit and preview collect directory evidence. The execution workflow uses the reviewed plan to move the account and reconcile direct group memberships. Version 2 GUI development is separate.

## Requirements and startup

Use elevated Windows PowerShell 5.1 with RSAT Active Directory. The live workflows require an enabled account with forest-root Enterprise Admin directory membership and an enabled Enterprise Admin SID in the current elevated token. Protected Users membership in the directory or token blocks the workflow. The audit entry point supports a same-identity UAC handoff and an optional Windows CSV file picker.

Run the included offline suites from the project folder.

~~~powershell
.\Tests\Test-ADMigrationAll.ps1
~~~

Copy the [fictional config](Config/MigrationConfig.example.json), [fictional mapping CSV](Config/GroupMappings.example.csv) and [sample input CSV](Examples/Migration.example.csv) to their working filenames.

~~~powershell
Copy-Item .\Config\MigrationConfig.example.json .\Config\MigrationConfig.json; Copy-Item .\Config\GroupMappings.example.csv .\Config\GroupMappings.csv; Copy-Item .\Examples\Migration.example.csv .\Examples\Migration.csv
~~~

Replace the sample values in the working files. See the [configuration reference](Docs/Configuration.md) for directions, CSV columns, and group decisions. The examples use reserved DNS names, fictional approvals, and synthetic account and group identifiers.

To check the examples locally without directory access or evidence writes, run the execution entry point with [what-if mode](Docs/Operations.md).

~~~powershell
.\Move-ADUserAccount.ps1 -CsvPath .\Examples\Migration.example.csv -ConfigPath .\Config\MigrationConfig.example.json -GroupMapPath .\Config\GroupMappings.example.csv -WhatIf
~~~

## Preview and move

Run a live read-only audit or generate an execution preview. Both use live AD reads and produce private local evidence.

~~~powershell
.\Get-ADUserMigrationAudit.ps1 -CsvPath .\Examples\Migration.csv -DryRun
.\Move-ADUserAccount.ps1 -CsvPath .\Examples\Migration.csv
~~~

Read the displayed path to review ExecutionPlan.json, ExecutionPreview.html and the accompanying evidence. Verify the source GUID, direction, target OU, blockers and each group action. Optionally use -ExpectedUserGUID to pin an independently verified GUID.

Use the exact reviewed plan path in $planPath. The execution step repeats the audit, validates input and evidence hashes, checks the RID Masters and requires typed MIGRATE followed by the sAMAccountName. A first-use plan expires after 24 hours.

~~~powershell
.\Move-ADUserAccount.ps1 -CsvPath .\Examples\Migration.csv -Execute -PlanPath $planPath -Confirm
~~~

The [operations guide](Docs/Operations.md) covers the ActiveSync cleanup workflow, execution order, recovery and evidence. Keep the run directory private. The repository tracks only an empty Logs placeholder.

## Validation and scope

The original pilot runs exercised both directions in earlier builds. This public packaging was tested offline on Windows PowerShell 5.1 using mocks and fictional fixtures. Current offline coverage includes plan and evidence integrity, configuration validation, one-move and target-only resume behavior, ActiveSync cleanup, and distribution membership changes. The successful live recovery found distribution membership already correct, so the incremental distribution-group write path was never exercised during the live pilots. Validate that path with representative groups in a non-production forest before authorizing live use.

Version 1 covers one user and explicitly reviewed direct membership changes. Profile translation, home-drive moves, NTFS ACL changes, bulk migration, automatic rollback, email delivery and ticket-system writes are outside its scope. Live results reflect the pinned domain controllers and leave sign-in, application access, mail delivery and replication confirmation to the operator.

## Remote execution

Clone or download the complete repository at a reviewed commit or release tag and run from this project folder. The CLI imports sibling modules and requires private working configuration and operator review.

~~~powershell
git clone https://github.com/joelcottrell/powershell-toolkit.git
~~~

Author is Joel Cottrell. [GPL-3.0 license](../../../LICENSE).
