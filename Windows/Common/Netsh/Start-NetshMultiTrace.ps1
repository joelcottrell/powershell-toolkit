<#	
.NOTES
	Name: netsh_multi_trace.ps1
	Author: Joel Cottrell
	Copyright: GPLv3
	Tags: windows netsh

.LICENSEURI
https://github.com/bigjoestretch/public/blob/main/LICENSE

.PROJECTURI
https://github.com/bigjoestretch/public/tree/main/Windows/Netsh

.ICONURI

.EXTERNALMODULEDEPENDENCIES

.REQUIREDSCRIPTS 

.EXTERNALSCRIPTDEPENDENCIES

.RELEASENOTES
v1.0 - 25/05/07 - Initial release of this script.
	
.SYNOPSIS
Captures three 60-minute netsh traces

.DESCRIPTION
This script does the following:

	Captures three 60-minute netsh traces
	Saves each with a timestamped .etl filename
	Compresses each completed trace into a .zip file using Compress-Archive   
	Includes error handling and auto-creates the output directory

.EXAMPLE
Example output: C:\Temp\nettrace_20250507_160002.zip

#>

# Define output directory
$traceDir = "C:\Temp"
if (-not (Test-Path $traceDir)) {
    try {
        New-Item -Path $traceDir -ItemType Directory -Force
        Write-Output "Created trace directory: $traceDir"
    } catch {
        Write-Error "Failed to create directory $traceDir. Exiting."
        exit 1
    }
}

# Function to start and stop a 60-minute trace, then zip it
function Start-TimedTrace {
    param (
        [int]$durationSeconds = 3600,
        [string]$outputDir
    )

    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $traceFileName = "nettrace_$timestamp.etl"
    $traceFilePath = Join-Path $outputDir $traceFileName
    $zipFilePath = Join-Path $outputDir ("nettrace_$timestamp.zip")

    # Start the trace
    try {
        Write-Output "`n[$(Get-Date -Format 'HH:mm:ss')] Starting trace: $traceFilePath"
        netsh trace start capture=yes tracefile="$traceFilePath" persistent=no overwrite=yes report=yes
    } catch {
        Write-Error "Failed to start netsh trace. Skipping this interval."
        return
    }

    # Wait for specified duration
    Write-Output "Capturing for $($durationSeconds / 60) minutes..."
    Start-Sleep -Seconds $durationSeconds

    # Stop the trace
    try {
        Write-Output "[$(Get-Date -Format 'HH:mm:ss')] Stopping trace..."
        netsh trace stop
        Write-Output "Trace saved: $traceFilePath"
    } catch {
        Write-Error "Failed to stop netsh trace properly."
        return
    }

    # Compress the trace file
    try {
        Write-Output "Compressing to: $zipFilePath"
        Compress-Archive -Path $traceFilePath -DestinationPath $zipFilePath -Force
        Remove-Item $traceFilePath -Force
        Write-Output "Compression complete. Original .etl file removed."
    } catch {
        Write-Error "Failed to compress trace file: $traceFilePath"
    }
}

# Run three 60-minute traces back to back
for ($i = 1; $i -le 3; $i++) {
    Write-Output "`n=== Trace $i of 3 ==="
    Start-TimedTrace -durationSeconds 3600 -outputDir $traceDir
}
