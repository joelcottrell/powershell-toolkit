# Reference

Detailed reference material: configuration schema, field definitions, valid
values, and links to vendor documentation.

---

## Configuration schema

`Config/settings.example.csv`

| Column | Required | Type | Valid values | Description |
| --- | --- | --- | --- | --- |
| `Name` | Yes | string | | Identifier for the setting. |
| `Value` | Yes | string | | The value to apply. |
| `Description` | No | string | | Free text, ignored by the script. |

Copy the example to a working file before use:

```powershell
Copy-Item .\Config\settings.example.csv .\Config\settings.csv
```

The working copy is ignored by git. The example is tracked. Never commit a file
containing live tenant identifiers, site tokens, or credentials.

---

## Parameter reference

| Parameter | Type | Default | Description |
| --- | --- | --- | --- |
| | | | |

---

## Exit codes

| Code | Meaning |
| --- | --- |
| 0 | Success |
| 1 | Failure |

---

## External documentation

- [Vendor documentation](https://example.com)
