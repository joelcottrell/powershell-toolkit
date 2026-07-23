# Operational Notes

## Recommended execution sequence

1. Copy the appropriate example CSV to its runtime filename.
2. Populate the CSV with reviewed values.
3. Run the script with `-WhatIf`.
4. Review the console preview and generated log.
5. Run without `-WhatIf` during the approved change window.
6. Validate the resulting vSwitches and port groups in vCenter.
7. Retain the log with the related change record when required.

## Existing standard vSwitches

An existing vSwitch does not block port-group creation. The script retrieves and reuses the existing vSwitch object, warns in the console, and continues processing its configured port groups.

## VLAN mismatches

The scripts intentionally do not change the VLAN of an existing port group. A mismatch is logged as a warning so the operator can investigate before making an explicit change.

## Standard vSwitch uplinks

Creating a standard vSwitch does not automatically assign a physical NIC. Review whether each new switch requires one or more `vmnic` uplinks, MTU settings, NIC teaming, failover order, security settings, or traffic shaping.

## Unattended execution

The `-Force` parameter bypasses the CSV approval prompt but does not bypass `-WhatIf` or PowerShell confirmation semantics. Use it only after the CSV has been independently reviewed and execution has been approved.

## Logs

Logs are written under the project `Logs` folder and are ignored by Git. Consider attaching the applicable log to the change ticket rather than committing it to the repository.
