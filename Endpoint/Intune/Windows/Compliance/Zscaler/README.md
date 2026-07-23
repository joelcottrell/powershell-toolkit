# Microsoft Intune - Custom Compliance - Zscaler Client

This Intune custom compliance policy is used to check the status of the Zsclaer Client Connector on a Windows machine. It attempts to checks whether your Internet connection runs through the ZScaler Internet Service. Based on the results, it wil mark the Windows machine compliant or not.

## Intune Configuration Policy

N/A

## Intune Compliance Detection Script

[Zscaler Internet Service](./Detect-Zscaler.ps1)

## Intune Compliance JSON

[Zscaler Internet Service Compliance Policy](./Detect-Zscaler.JSON)

For compliance, the expected results are:

- ZScalerStatus:You are accessing the Internet via Zscaler Cloud:

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
