# Microsoft Intune - Windows app (Win32) - Datto RMM

This Intune Windows app (Win32) deploys the Kaseya Datto RMM application to assigned users/devices in Microsoft Intune (formerlly Microsoft Endpoint)

## Required parameters

The install script takes two tenant-specific values. Supply your own before packaging:

| Parameter | Where to find it |
| --- | --- |
| `-Platform` | The subdomain of your Datto RMM portal URL, `https://<platform>.rmm.datto.com` |
| `-SiteID` | The GUID of the target site, under **Sites > &lt;your site&gt; > Settings** |

> The SiteID is the only token needed to download an agent installer bound to your site.
> Treat it as a secret and keep live values out of source control.

## Intune Windows app (Win32) Configuration
Below are the settings configured under the ***Program*** section of the app configuration:

| Description | Value |
| --- | --- |
| Install command | **powershell.exe -ExecutionPolicy Bypass -File [Install-DattoRMMAgent.ps1](./Install-DattoRMMAgent.ps1) -Platform "&lt;platform&gt;" -SiteID "&lt;site-guid&gt;"** |
| Uninstall command | **[Uninstall-DattoRMMAgent.cmd](./Uninstall-DattoRMMAgent.cmd)** |
| Installation time required (mins) | **60** |
| Allow available uninstall | **Yes** |
| Install behavior | **System** |
| Device restart behavior | **App install may force a device restart** |
|  |  |
| Return codes | **0 Success** |
|  | **1707 Success** |
|  | **3010 Soft reboot** |
|  | **1641 Hard reboot** |
|  | **1618 Retry** |

## Intune Windows app (Win32) Requirements
Below are the settings configured under the ***Requirements*** section of the app configuration:

| Description | Value |
| --- | --- |
| Operating system architecture | **x64** |
| Minimum operating system | **Windows 10 1909** |
| Disk space required | **(MB)** |
| No Disk space required | **(MB)** |
| Physical memory required | **(MB)** |
| No Physical memory required | **(MB)** |
| Minimum number of logical processors required | **No Minimum number of logical processors required** |
| Minimum CPU speed required (MHz) | **No Minimum CPU speed required (MHz)** |
| Additional requirement rules | **No Additional requirement rules** |

## Intune Windows app (Win32) Detection rules
Below are the settings configured under the ***Detection rules*** section of the app configuration:

| Description | Value |
| --- | --- |
| Rules format | **Manually configure detection rules** |
|  |  |
| **Detection rules** |  |
| Rule type | **File** |
| Path | C:\Program Files (x86)\CentraStage |
| File or folder | **Gui.exe** |
| Detection method | **File or folder exists** |
| Associated with a 32-bit app on 64-bit clients | **No** |

### Intune Windows app (Win32) Dependencies
Below are the settings configured under the ***Dependencies*** section of the app configuration:

| Description | Value |
| --- | --- |
| Dependencies | **No Dependencies** |

### Intune Windows app (Win32) Supercedence
Below are the settings configured under the ***Supercedence*** section of the app configuration:

| Description | Value |
| --- | --- |
| Supercedence | **No Supercedence** |
