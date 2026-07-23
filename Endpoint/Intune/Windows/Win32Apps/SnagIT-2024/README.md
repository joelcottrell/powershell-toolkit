# Microsoft Intune - Windows app (Win32) - Snagit 2024

This Intune Windows app (Win32) deploys the Snagit 2024 application to assigned users/devices in Microsoft Intune (formerlly Microsoft Endpoint)

## Intune Windows app (Win32) Configuration
Below are the settings configured under the ***Program*** section of the app configuration:

| Description | Value |
| --- | --- |
| Install command | **powershell.exe -ExecutionPolicy Bypass -File [install-snagit-2024.ps1](./install-snagit-2024.ps1)** |
| Uninstall command | **powershell.exe -ExecutionPolicy Bypass -File [uninstall-snagit-2024.ps1](./uninstall-snagit-2024.ps1)** |
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
| Path | %ProgramFiles%\TechSmith\Snagit 2024\ |
| File or folder | **SnagitEditor.exe** |
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
