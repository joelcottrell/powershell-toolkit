# App Update Maintenance

## Purpose

App Update Maintenance is a separate, short-lived WinGet maintenance workload.
It is intentionally not part of the continuous LocalSystem policy service.

The Windows Package Manager CLI is delivered as a packaged application and is
not supported in LocalSystem context. The updater therefore runs in the
configured administrator's interactive user context, with highest privileges,
on a daily schedule.

Because each run exits when maintenance completes, it does not leave a
persistent PowerShell or Windows Terminal window open.

## Modes

### All

Runs the equivalent of:

    winget upgrade --all --silent --accept-source-agreements --accept-package-agreements --disable-interactivity

Packages listed in ExcludedPackages are pinned first so WinGet excludes them
from upgrade --all.

### AllowList

Only package IDs listed in Packages are targeted.

## PowerShell exception

Microsoft.PowerShell is excluded in the tracked example configuration. WinGet
can report a newer PowerShell release while refusing an in-place upgrade when
the installed and available packages use different installer technologies.

Keep the package excluded until its current installation path has been
standardized and a direct upgrade has been tested successfully.

## Test first

From PowerShell 7:

    .\Test-AppUpdateMaintenance.ps1

Audit mode does not install packages or create missing exclusion pins.

## Install

Example:

    .\Install-AppUpdateMaintenance.ps1 -Enable -Mode All -StartNow

To place the task in an existing Task Scheduler folder:

    .\Install-AppUpdateMaintenance.ps1 -TaskPath '\BCH-IT\' -Enable -Mode All -StartNow

## Logs

Installed maintenance logs are written below:

    C:\ProgramData\DesktopPolicy-Guard\Logs\AppUpdateMaintenance

Each run creates a text log and a JSON report.

## Important behavior

- WinGet pins are not removed automatically during uninstall.
- Excluded package IDs remain excluded from winget upgrade --all while pinned.
- User-scoped packages are visible because the task runs in user context.
- The task runs with highest privileges for the selected user.
- StartWhenAvailable handles missed scheduled runs.
- A four-hour execution limit prevents a stuck installer from running forever.
