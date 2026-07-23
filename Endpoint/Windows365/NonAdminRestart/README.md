# Windows 365 - Non-Admin Restart

Lets standard users restart a Windows 365 Cloud PC without administrative rights.

- ✅ Grants `SeShutdownPrivilege` to a security principal
- 🔁 Idempotent - re-running makes no further change
- 🔍 Resolves the principal to a SID before touching policy
- 🧹 Cleans up its temporary policy files even on failure

---

## Grant-ShutdownPrivilege.ps1

[Grant-ShutdownPrivilege.ps1](./Grant-ShutdownPrivilege.ps1)

Exports local security policy with `secedit`, adds the principal's SID to the
`SeShutdownPrivilege` user right if it is not already present, and imports the policy back.

### Requirements

| Requirement | Detail |
| --- | --- |
| PowerShell | 5.1 or later |
| Permissions | Elevated session. The script checks and exits if not elevated |
| Target | Any Windows device; written for Windows 365 Cloud PCs |

### Usage

```powershell
# Check whether a change is needed, without applying it
.\Grant-ShutdownPrivilege.ps1 -WhatIf

# Grant to the local Users group
.\Grant-ShutdownPrivilege.ps1

# Grant to a specific group
.\Grant-ShutdownPrivilege.ps1 -Principal "CONTOSO\Cloud PC Users"
```

| Parameter | Required | Description |
| --- | --- | --- |
| `-Principal` | No | Principal to grant the right to. Defaults to the local `Users` group |

### Existing object behaviour

Safe to re-run. If the principal already holds the right, the script reports it and exits
without writing. The original version appended the SID unconditionally, so repeated runs
accumulated duplicate entries in the policy.

---

## Safety features

- Resolves the principal to a SID **before** exporting policy, so a typo fails early
- Reads the current policy and exits unchanged if the right is already held
- Supports `-WhatIf`
- Checks the `secedit /configure` exit code rather than assuming success
- Removes its temporary `.inf` and `.sdb` files in a `finally` block

---

## Important scope notes

**Managed policy wins.** This edits *local* security policy. On a device where Group Policy
or an Intune security baseline also defines `SeShutdownPrivilege`, the managed setting
overwrites this at the next policy refresh, and it will look as though the script silently
stopped working. Confirm no competing policy exists before relying on it.

This script deliberately does **not**:

- Revoke the privilege. There is no matching revoke script; remove the entry through the
  same policy channel that granted it.
- Grant any other user right.
- Restart the machine.

Granting shutdown rights on a shared or multi-session host lets any standard user restart
it out from under everyone else. On a single-user Cloud PC that is the intent; elsewhere,
consider carefully.

---

## Remote execution

See the header of [Grant-ShutdownPrivilege.ps1](./Grant-ShutdownPrivilege.ps1) for the
three supported invocation patterns.

> Downloading and reviewing before running is the recommended pattern. For production use,
> pin the URL to a release tag rather than `main`.

---

## Author

**Joel Cottrell** - [github.com/joelcottrell](https://github.com/joelcottrell)

## License

See [LICENSE](../../../LICENSE).

---

> Always test in a non-production environment first.
