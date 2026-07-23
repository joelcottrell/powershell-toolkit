# CSV Reference

## Standard vSwitch configuration

Runtime file: `Config/portgroups.csv`

| Column | Required | Description |
|---|---:|---|
| `vSwitchName` | Yes | Name of the standard vSwitch to find or create on each ESXi host. |
| `PortGroup` | Yes | Name of the standard port group to find or create. |
| `VlanID` | Yes | VLAN identifier. The script accepts values from 0 through 4095. |

```csv
vSwitchName,PortGroup,VlanID
vSwitch1,Production,100
vSwitch1,Development,200
```

The script groups rows by `vSwitchName`, creates or reuses the switch, then processes each port group assigned to that switch.

## Distributed port-group configuration

Runtime file: `Config/vdsportgroups.csv`

| Column | Required | Description |
|---|---:|---|
| `vdsName` | Yes | Name of an existing vSphere Distributed Switch. |
| `PortGroup` | Yes | Name of the distributed port group to find or create. |
| `VlanID` | Yes | Access VLAN identifier. The script accepts values from 0 through 4094. |

```csv
vdsName,PortGroup,VlanID
Production-VDS,Production-App,100
Production-VDS,Production-Web,200
```

## Validation rules

Both scripts stop before connecting to vCenter when any of the following conditions are detected:

- Required CSV file is missing
- CSV contains no data rows
- Required columns are missing
- Required values are empty
- VLAN value is not an integer
- VLAN value is outside the supported range
- Duplicate switch and port-group combinations are present

## Source-control guidance

Commit only the `.example.csv` templates. Runtime files are excluded through the project `.gitignore` because they may contain environment-specific infrastructure names and VLAN information.
