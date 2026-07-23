<#
    Usage examples for <Project-Name>.

    This file is documentation, not a script to run end to end. Copy the block
    you need. Every example is written to be safe to read before it is safe to
    run - destructive examples are commented and marked.
#>

# ---------------------------------------------------------------------------
# 1. Preview without changing anything
# ---------------------------------------------------------------------------

.\Verb-Noun.ps1 -ParameterName "value" -WhatIf

# ---------------------------------------------------------------------------
# 2. Basic run
# ---------------------------------------------------------------------------

.\Verb-Noun.ps1 -ParameterName "value"

# ---------------------------------------------------------------------------
# 3. Run against a configuration file
# ---------------------------------------------------------------------------

Copy-Item .\Config\settings.example.csv .\Config\settings.csv
# Edit .\Config\settings.csv for your environment, then:
.\Verb-Noun.ps1 -ParameterName "value" -Verbose

# ---------------------------------------------------------------------------
# 4. Capture a transcript
# ---------------------------------------------------------------------------

Start-Transcript -Path ".\Logs\run_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
.\Verb-Noun.ps1 -ParameterName "value" -Verbose
Stop-Transcript
