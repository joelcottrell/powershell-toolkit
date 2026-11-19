# Configuration reference

Use the examples as templates for local working copies. Version 1 requires a root domain and its direct child in the same forest. All example DNS names, OUs, users, references and SID values are fictional.

| MigrationConfig.json key | Expected value |
| --- | --- |
| SchemaVersion | 1 |
| ForestRoot | The root FQDN discovered by Active Directory |
| ChildDomain | The direct child FQDN of ForestRoot |
| Directions | ROOT_TO_CHILD and CHILD_TO_ROOT with matching SourceDomain and TargetDomain values and a DefaultTargetOU DN for each target |
| ApprovedChildObjectClasses | Exact schema class names for audit review. The cleanup workflow independently restricts deletion to msExchActiveSyncDevices and msExchActiveSyncDevice. |
| GroupCatalog.Prefixes | Nonempty list of literal alphanumeric group family prefixes |
| GroupCatalog.TrailingNameSuffix | Optional literal alphanumeric token stripped when it appears at the end of a group name after a separator. It affects candidate suggestions only. |
| GroupCatalog limits | MaxInventoryGroups, MaxSelectedGroups and MaxCandidatePairs, each from 1 to 100000 |

The input CSV takes exactly one row. Include SamAccountName, MigrationDirection, TargetOU and ChangeReference. Leave TargetOU blank to use the configured default. Quote a distinguished name that contains commas. Use a tracking reference with an alphabetic prefix and numeric suffix, such as CHANGE-101.

## Group decisions

The mapping CSV columns are MigrationDirection, SourceGroupSID, TargetGroupSID, Action, ApprovedBy, ApprovalReference, SourceUserGUID and ChangeReference. Preserve the header even if there are no mappings. Provide only reviewed decisions.

| Action | Effect and approval |
| --- | --- |
| Retain | Keep the same compatible group identity. Leave TargetGroupSID blank. Compatible universal and domain-local memberships and existing target-domain global memberships can be retained. |
| Map | Replace the source group with the approved exact target-domain SID. V1 checks the group category and verifies the replacement links. |
| Omit | Approve a specific account's loss of a source non-primary global membership. Leave TargetGroupSID blank and supply the exact SourceUserGUID, matching ChangeReference, ApprovedBy and ApprovalReference. |

Review all applicable rows. Scoped and unscoped rows that both apply to the same source SID block execution. Names and nesting suggest candidates only. Regenerate the execution preview after touching the input CSV, mapping CSV or configuration.
