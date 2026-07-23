# Proactive Remediations

Endpoint Analytics Proactive Remediations - Detection and Remediations scripts

Proactive Remediations are Intune's take on ConfigMgr's Configuration Item/Baseline. They are PowerShell scripts that consist of a detection and remediation script. The detection script evaluates the current state and only runs the remediation script if it does not match the desired state.

You can access Proactive Remediations in the [Microsoft Endpoint Manager](https://endpoint.microsoft.com/) portal.

Reports / Endpoint analytics / Proactive Remediations

## The Intune Custom Compliance Policy Repository

This repository contains detection/discovery scripts and JSON files for Microsoft Intune *Custom* comppliance scripts and policies. Each Custom compliance contains the following artifacts.

| Artifact | Description |
| ---------|-------------|
| README.md | Description of the custom proactive remediation with references to the detection script and remediation script |
| Detect-.ps1 | PowerShell detection script |
| Remediate-.ps1 |  PowerShell detection script.|

## Proactive Remediations

```
   |-Proactive Remediations
   |---Change WinVer and OEM Info
   |---Clear Microsoft Apps Cache
   |---Create Local Admin Account
   |---Disable Windows Fast Boot
   |---Microsoft Store Forced Auto Update
   |---Uninstall App
   |------Zscaler
   |---Windows Update
   ```

## 1. Change WinVer and OEM Info

When moving to WUfB you may encounter a number of devices holding onto a setting to disable automatic updates which had been applied to a legacy GPO.

This proactive remediation will enable automatic updates if they are disabled

Non-Compliant device look as follows:

![AutoUpdateDisabled](images/AutoUpdateDisabled.png)

Desired State:

"HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU\NoAutoUpdate" = 0

<br>

## 2. Clear Microsoft Apps Cache

This proactive remediation will check if the ClickToRunSvc service is running and if not, start it. It is based on the built-in proactive remediation by Microsoft, only with changes since I noticed the original is incorrectly coded. Here is an example of the incorrect code:

```powershell
$ctr = 0
while ($curSvcStat -eq "Stopped") {
    Start-Sleep -Seconds 5
    ctr++ # <-- problem here and below. Should be $ctr not ctr.
    if (ctr -eq 12) {
        Write-Output "Office C2R service could not be started after 60 seconds"
        exit 1
    }
}
```

The "$ctr" variable is later written simply as "ctr" (no $) which PowerShell will treat as a command/function and would have resulted in an "infinite loop" as $ctr will stay on 0.

![ctrError](images/ctrError.png)

The corrected code looks as follows:

```powershell
$ctr = 0
while ($curSvcStat -eq "Stopped") {
    Start-Sleep -Seconds 5
    $ctr++
    if ($ctr -eq 12) {
        Write-Output "Office C2R service could not be started after 60 seconds"
        exit 1
    }
}
```

Another problem found with the Microsoft code. If $curSvcStat is set as "Stopped", it will always be stopped until the variable is updated by running the cmdlet again, which is isn't. So even if the service does start (Running) the variable will always be "Stopped"

```powershell
while ($curSvcStat -eq "Stopped")
```

Changed the code as follows:

```powershell
while ((Get-Service $svcCur).Status -ne "Running")
```

<br>

## 3. Create Local Admin Account

The Office Click-to-Run updater tool is often always lagging behind on updates. This proactive remediation will check the registry for when the machine last checked for updates, and if more than 3 days ago, clear the reg key and start the Scheduled task.

The UpdateDetectionLastRunTime key value is in LDAP/Win32 FILETIME which needs to be converted into date/time which is human readable. Can do this in PowerShell which I found from the link below

https://www.epochconverter.com/ldap

<br>

## 4. Uninstall App - Zscaler

When moving to WUfB you may encounter a number of devices holding onto a setting to disable automatic updates which had been applied to a legacy GPO.

This proactive remediation will enable automatic updates if they are disabled

Non-Compliant device look as follows:

![AutoUpdateDisabled](images/AutoUpdateDisabled.png)

Desired State:

"HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU\NoAutoUpdate" = 0

<br>

## 5. Windows Update

When moving to WUfB you may encounter a number of devices holding onto a setting to disable automatic updates which had been applied to a legacy GPO.

This proactive remediation will enable automatic updates if they are disabled

Non-Compliant device look as follows:

![AutoUpdateDisabled](images/AutoUpdateDisabled.png)

Desired State:

"HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU\NoAutoUpdate" = 0

<br>
