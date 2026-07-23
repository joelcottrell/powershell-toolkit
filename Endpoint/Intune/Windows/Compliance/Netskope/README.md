# Microsoft Intune - Custom Compliance - Netskope Client

This Intune custom compliance policy is used to check the status of Netskope on a Windows machine. It attempts to detect whether the Netskope client is running on the machine. Based on the results, it wil mark the Windows machine compliant or not.

## Intune Configuration Policy

N/A

## Intune Compliance Detection Script

[Netskope Client service](./Detect-Netskope.ps1)

## Intune Compliance JSON

[Netskope Client service Compliance Policy](./Detect-Netskope.JSON)

For compliance, the expected results are:

- ServiceState:4 ([Running](https://learn.microsoft.com/en-us/dotnet/api/system.serviceprocess.servicecontrollerstatus?view=dotnet-plat-ext-8.0))
- ServiceStartupMode:2 ([Automatic](https://learn.microsoft.com/en-us/dotnet/api/system.serviceprocess.servicestartmode?view=dotnet-plat-ext-8.0))

## Check Compliance Results

Run the below command in PowerShell to check the compliance script results on the device.

```powershell
# Trigger Intune Synch
Start-Process -FilePath "C:\Program Files (x86)\Microsoft Intune Management Extension\Microsoft.Management.Services.IntuneWindowsAgent.exe" -ArgumentList intunemanagementextension://synccompliance
```

```powershell
# Chck the logs
Get-Content -Path "c:\programdata\Microsoft\IntuneManagementExtension\Logs\AgentExecutor.log" | Select-String -Pattern 'ServiceState|ServiceStartupMode'
Get-Content -Path "C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\HealthScripts.log" | Select-String -Pattern 'ServiceState|ServiceStartupMode'
```
