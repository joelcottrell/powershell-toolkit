# Microsoft Windows - Netsh

This Netsh PowerShell script performs the following:

✅ Captures three 60-minute netsh traces

🕒 Saves each with a timestamped .etl filename

📦 Compresses each completed trace into a .zip file using Compress-Archive

❗ Includes error handling and auto-creates the output directory

## Netsh Multi Trace Script

[Start-NetshMultiTrace](./Start-NetshMultiTrace.ps1)

## 🔧 Requirements:

PowerShell 5.0+ (for Compress-Archive)

Sufficient disk space in C:\TempRun the below command in PowerShell to check the compliance script results on the device.

## 📁 Output:
Each capture will result in a .zip file like:

```powershell
# makefile
C:\Temp\nettrace_20250507_160002.zip
```
