<#
.SYNOPSIS
    Creates distributed port groups on existing vSphere Distributed Switches.

.DESCRIPTION
    The script performs the following actions:

    1. Initializes relative paths and creates a relative Logs folder.
    2. Validates VMware PowerCLI availability.
    3. Validates and imports vdsportgroups.csv from the project Config folder.
    4. Displays the validated CSV configuration for review.
    5. Requires Y or N confirmation before connecting to vCenter.
    6. Connects to the specified vCenter Server.
    7. Locates each vSphere Distributed Switch listed in the CSV.
    8. Creates missing distributed port groups.
    9. Detects existing distributed port groups and VLAN mismatches.
   10. Displays detailed progress, console step headers, and a summary.
   11. Writes timestamped success, warning, and error details to a log file.
   12. Disconnects from vCenter.

.PARAMETER vCenter
    Specifies the vCenter Server FQDN or IP address. When omitted, the script
    prompts for a value.

.PARAMETER Credential
    Specifies credentials used to connect to vCenter. When omitted, the script
    displays a credential prompt.

.PARAMETER CsvFileName
    Specifies the CSV filename located in the project Config folder. The default value
    is vdsportgroups.csv.

.PARAMETER Force
    Skips the interactive CSV confirmation. This is useful for an approved
    scheduled or unattended execution.

.EXAMPLE
    .\New-DistributedPortGroups.ps1

.EXAMPLE
    .\New-DistributedPortGroups.ps1 -vCenter "itprdvc.chboston.org" -WhatIf

.EXAMPLE
    .\New-DistributedPortGroups.ps1 -vCenter "itprdvc.chboston.org" -Force

.NOTES
    File Name : New-DistributedPortGroups.ps1
    Author    : Joel Cottrell
    Created   : 2026-07-21
    Version   : 1.4.0
    Location  : Portable. Uses paths relative to the project directory.

    Changelog:
        1.4.0 - 2026-07-22
            - Aligned the project with the existing powershell-toolkit repository.
            - Moved the scripts directly into the project root.
            - Updated relative Config and Logs path resolution.
            - Updated repository documentation, examples, and tests.

        1.3.0 - 2026-07-21
            - Added GitHub-ready project folder support.
            - Moved runtime CSV input to the relative Config folder.
            - Moved runtime logs to the relative project Logs folder.
            - Added guidance when only the example CSV template exists.

        1.2.0 - 2026-07-21
            - Added formatted CSV configuration preview.
            - Added Y or N confirmation before connecting to vCenter.
            - Added optional Force parameter for unattended execution.
            - Added relative logging, detailed progress, step headers,
              existing-object warnings, VLAN mismatch checks, and summaries.

        1.1.0 - 2026-07-21
            - Added relative CSV path and basic error handling.

        1.0.0 - 2026-07-21
            - Initial script.

    Requirements:
        - Windows PowerShell 5.1 or PowerShell 7
        - VMware PowerCLI or VCF PowerCLI
        - Permissions to read distributed switches and port groups
        - Permissions to create distributed port groups
        - vdsportgroups.csv stored in the project Config folder

    Required CSV columns:
        vdsName
        PortGroup
        VlanID

    VLAN behavior:
        - VLAN IDs 1 through 4094 create an access VLAN configuration.
        - VLAN ID 0 omits the VlanId parameter and leaves the new distributed
          port group with the platform default VLAN configuration.
#>

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
param (
    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$vCenter,

    [Parameter()]
    [System.Management.Automation.PSCredential]$Credential,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$CsvFileName = 'vdsportgroups.csv',

    [Parameter()]
    [switch]$Force
)

# ============================================================================
# SECTION 1: Script initialization and relative paths
# ============================================================================

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$TotalConsoleSteps = 6
$VIServer          = $null
$FatalError        = $false
$ExecutionApproved = $false

$ScriptRoot    = $PSScriptRoot
$ProjectRoot   = $ScriptRoot
$ConfigFolder  = Join-Path -Path $ProjectRoot -ChildPath 'Config'
$CsvPath       = Join-Path -Path $ConfigFolder -ChildPath $CsvFileName
$ExampleCsvPath = Join-Path -Path $ConfigFolder -ChildPath 'vdsportgroups.example.csv'
$LogsFolder    = Join-Path -Path $ProjectRoot -ChildPath 'Logs'

try {
    if (-not (Test-Path -LiteralPath $LogsFolder -PathType Container)) {
        New-Item -Path $LogsFolder -ItemType Directory -Force -ErrorAction Stop | Out-Null
    }
}
catch {
    Write-Error "Unable to create the Logs folder '$LogsFolder': $($_.Exception.Message)"
    exit 1
}

$Timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$LogPath   = Join-Path -Path $LogsFolder -ChildPath "DistributedPortGroupDeployment_$Timestamp.log"

$Statistics = [ordered]@{
    RowsProcessed          = 0
    PortGroupsCreated      = 0
    PortGroupsExisting     = 0
    PortGroupsNotCreated   = 0
    SwitchesNotFound       = 0
    VlanMismatches         = 0
    VlanComparisonsSkipped = 0
    Warnings               = 0
    Failures               = 0
}

# ============================================================================
# SECTION 2: Supporting functions
# ============================================================================

function Write-Log {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateSet('INFO', 'SUCCESS', 'WARNING', 'ERROR')]
        [string]$Level,

        [Parameter(Mandatory)]
        [string]$Message
    )

    $LogTimestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff'
    $LogEntry     = '{0} [{1,-7}] {2}' -f $LogTimestamp, $Level, $Message

    try {
        Add-Content -LiteralPath $script:LogPath -Value $LogEntry -Encoding UTF8 -ErrorAction Stop
    }
    catch {
        Write-Warning "Unable to write to the log file: $($_.Exception.Message)"
    }

    switch ($Level) {
        'INFO'    { Write-Host "[INFO]    $Message" -ForegroundColor Gray }
        'SUCCESS' { Write-Host "[SUCCESS] $Message" -ForegroundColor Green }
        'WARNING' { Write-Warning $Message }
        'ERROR'   { Write-Host "[ERROR]   $Message" -ForegroundColor Red }
    }
}

function Show-ConsoleStep {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [int]$StepNumber,

        [Parameter(Mandatory)]
        [string]$Title
    )

    $Separator = '=' * 78
    $StepText  = "STEP $StepNumber OF $script:TotalConsoleSteps - $Title"

    Write-Host ''
    Write-Host $Separator -ForegroundColor Cyan
    Write-Host $StepText -ForegroundColor Cyan
    Write-Host $Separator -ForegroundColor Cyan
    Write-Log -Level INFO -Message $StepText
}

function Confirm-CsvConfiguration {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [object[]]$CsvData,

        [Parameter(Mandatory)]
        [string]$CsvPath,

        [Parameter()]
        [switch]$Force
    )

    $UniqueSwitches = @($CsvData | Select-Object -ExpandProperty vdsName -Unique)

    Write-Host ''
    Write-Host ('=' * 78) -ForegroundColor Cyan
    Write-Host 'CSV CONFIGURATION REVIEW' -ForegroundColor Cyan
    Write-Host ('=' * 78) -ForegroundColor Cyan
    Write-Host ''
    Write-Host 'I successfully read and validated the CSV file:' -ForegroundColor Green
    Write-Host "  $CsvPath" -ForegroundColor Gray
    Write-Host ''
    Write-Host "Configuration rows found    : $($CsvData.Count)" -ForegroundColor Cyan
    Write-Host "Unique distributed switches : $($UniqueSwitches.Count)" -ForegroundColor Cyan
    Write-Host ''
    Write-Host 'The following distributed port-group configuration will be processed:' -ForegroundColor White
    Write-Host ''

    $Preview = $CsvData |
        Sort-Object -Property vdsName, PortGroup |
        Select-Object `
            @{Name = 'Distributed Switch'; Expression = { $_.vdsName } }, `
            @{Name = 'Port Group'; Expression = { $_.PortGroup } }, `
            @{Name = 'VLAN ID'; Expression = { $_.VlanID } } |
        Format-Table -AutoSize |
        Out-String

    Write-Host $Preview
    Write-Host ('-' * 78) -ForegroundColor DarkCyan

    if ($Force) {
        Write-Host 'The Force parameter was supplied. CSV confirmation is being skipped.' -ForegroundColor Yellow
        Write-Log -Level WARNING -Message 'CSV review confirmation was bypassed with the Force parameter.'
        return $true
    }

    Write-Host 'Would you like to proceed with this configuration?' -ForegroundColor Yellow
    Write-Host ''
    Write-Host '  Type Y and press Enter for Yes.' -ForegroundColor Green
    Write-Host '  Type N and press Enter for No.' -ForegroundColor Red
    Write-Host ''

    while ($true) {
        $Response = (Read-Host 'Enter Y or N').Trim()

        switch -Regex ($Response) {
            '^(Y|YES)$' {
                Write-Host ''
                Write-Host '[+] Confirmation received. Continuing with the script.' -ForegroundColor Green
                Write-Log -Level SUCCESS -Message 'The user reviewed the CSV configuration and approved execution.'
                return $true
            }

            '^(N|NO)$' {
                Write-Host ''
                Write-Host '[!] Execution cancelled by the user. No vCenter connection or changes were made.' -ForegroundColor Yellow
                Write-Log -Level WARNING -Message 'The user reviewed the CSV configuration and cancelled execution.'
                return $false
            }

            default {
                Write-Warning "Invalid response '$Response'. Enter Y for Yes or N for No."
            }
        }
    }
}

function Get-ExistingVDPortgroupVlanId {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [object]$VDPortgroup
    )

    try {
        $VlanObject = $VDPortgroup.ExtensionData.Config.DefaultPortConfig.Vlan

        if ($null -ne $VlanObject -and $VlanObject.PSObject.Properties.Name -contains 'VlanId') {
            return [int]$VlanObject.VlanId
        }
    }
    catch {
        return $null
    }

    return $null
}

# ============================================================================
# SECTION 3: Main execution
# ============================================================================

try {
    Show-ConsoleStep -StepNumber 1 -Title 'Initializing script and validating prerequisites'

    Write-Log -Level INFO -Message "Script directory: $ScriptRoot"
    Write-Log -Level INFO -Message "Project directory: $ProjectRoot"
    Write-Log -Level INFO -Message "Configuration directory: $ConfigFolder"
    Write-Log -Level INFO -Message "CSV path: $CsvPath"
    Write-Log -Level INFO -Message "Log path: $LogPath"

    if (-not (Get-Command -Name Connect-VIServer -ErrorAction SilentlyContinue)) {
        Import-Module VMware.PowerCLI -ErrorAction SilentlyContinue
    }

    $RequiredCommands = @(
        'Connect-VIServer',
        'Disconnect-VIServer',
        'Get-VDSwitch',
        'Get-VDPortgroup',
        'New-VDPortgroup'
    )

    $MissingCommands = @(
        foreach ($CommandName in $RequiredCommands) {
            if (-not (Get-Command -Name $CommandName -ErrorAction SilentlyContinue)) {
                $CommandName
            }
        }
    )

    if ($MissingCommands.Count -gt 0) {
        throw "Required PowerCLI commands are unavailable: $($MissingCommands -join ', ')"
    }

    Write-Log -Level SUCCESS -Message 'All required PowerCLI commands are available.'

    # ========================================================================
    # SECTION 4: CSV validation and import
    # ========================================================================

    Show-ConsoleStep -StepNumber 2 -Title 'Validating and importing the CSV configuration'

    if (-not (Test-Path -LiteralPath $CsvPath -PathType Leaf)) {
        if (Test-Path -LiteralPath $ExampleCsvPath -PathType Leaf) {
            throw "The required CSV file was not found: $CsvPath. Copy '$ExampleCsvPath' to '$CsvPath', then update it with your environment values."
        }

        throw "The required CSV file was not found: $CsvPath"
    }

    $CsvData = @(Import-Csv -LiteralPath $CsvPath -ErrorAction Stop)

    if ($CsvData.Count -eq 0) {
        throw "The CSV file does not contain any configuration rows: $CsvPath"
    }

    $RequiredColumns = @('vdsName', 'PortGroup', 'VlanID')
    $AvailableColumns = @($CsvData[0].PSObject.Properties.Name)
    $MissingColumns = @($RequiredColumns | Where-Object { $_ -notin $AvailableColumns })

    if ($MissingColumns.Count -gt 0) {
        throw "The CSV is missing required columns: $($MissingColumns -join ', ')"
    }

    $CsvRowNumber = 1

    foreach ($Row in $CsvData) {
        $CsvRowNumber++
        $Row.vdsName   = ([string]$Row.vdsName).Trim()
        $Row.PortGroup = ([string]$Row.PortGroup).Trim()

        if ([string]::IsNullOrWhiteSpace($Row.vdsName)) {
            throw "CSV row $CsvRowNumber contains an empty vdsName."
        }

        if ([string]::IsNullOrWhiteSpace($Row.PortGroup)) {
            throw "CSV row $CsvRowNumber contains an empty PortGroup value."
        }

        $ParsedVlanId = 0
        $VlanIsValid = [int]::TryParse(([string]$Row.VlanID).Trim(), [ref]$ParsedVlanId)

        if (-not $VlanIsValid) {
            throw "CSV row $CsvRowNumber contains an invalid VLAN ID: '$($Row.VlanID)'"
        }

        if ($ParsedVlanId -lt 0 -or $ParsedVlanId -gt 4094) {
            throw "CSV row $CsvRowNumber contains VLAN ID '$ParsedVlanId'. The supported range for this script is 0 through 4094."
        }

        $Row.VlanID = $ParsedVlanId
    }

    $DuplicateEntries = @(
        $CsvData |
            Group-Object -Property vdsName, PortGroup |
            Where-Object { $_.Count -gt 1 }
    )

    if ($DuplicateEntries.Count -gt 0) {
        throw "Duplicate distributed-switch and port-group combinations were found: $($DuplicateEntries.Name -join '; ')"
    }

    Write-Log -Level SUCCESS -Message "Imported $($CsvData.Count) configuration row(s)."
    Write-Log -Level SUCCESS -Message "Identified $(@($CsvData | Select-Object -ExpandProperty vdsName -Unique).Count) unique distributed switch configuration(s)."

    # ========================================================================
    # SECTION 5: CSV review and execution confirmation
    # ========================================================================

    Show-ConsoleStep -StepNumber 3 -Title 'Reviewing the CSV configuration and requesting confirmation'

    $ExecutionApproved = Confirm-CsvConfiguration -CsvData $CsvData -CsvPath $CsvPath -Force:$Force

    if (-not $ExecutionApproved) {
        Write-Log -Level INFO -Message 'Script execution ended before connecting to vCenter.'
        return
    }

    # ========================================================================
    # SECTION 6: vCenter connection
    # ========================================================================

    Show-ConsoleStep -StepNumber 4 -Title 'Collecting connection information and connecting to vCenter'

    if ([string]::IsNullOrWhiteSpace($vCenter)) {
        $vCenter = (Read-Host 'What is the FQDN of your vCenter?').Trim()
    }

    if ([string]::IsNullOrWhiteSpace($vCenter)) {
        throw 'A vCenter FQDN or IP address must be provided.'
    }

    if ($null -eq $Credential) {
        $Credential = Get-Credential -Message "Enter credentials for $vCenter"
    }

    if ($null -eq $Credential) {
        throw 'No vCenter credentials were provided.'
    }

    Write-Log -Level INFO -Message "Connecting to vCenter: $vCenter"
    $VIServer = Connect-VIServer -Server $vCenter -Credential $Credential -ErrorAction Stop
    Write-Log -Level SUCCESS -Message "Connected to vCenter: $($VIServer.Name)"

    # ========================================================================
    # SECTION 7: Distributed port-group processing
    # ========================================================================

    Show-ConsoleStep -StepNumber 5 -Title 'Creating and validating distributed port groups'

    $TotalRows = $CsvData.Count
    $RowIndex  = 0

    foreach ($Row in $CsvData) {
        $RowIndex++
        $VdsName       = ([string]$Row.vdsName).Trim()
        $PortGroupName = ([string]$Row.PortGroup).Trim()
        $VlanId        = [int]$Row.VlanID
        $Statistics.RowsProcessed++

        Write-Progress `
            -Id 0 `
            -Activity 'Configuring distributed port groups' `
            -Status "Configuration $RowIndex of $TotalRows" `
            -CurrentOperation "Checking '$PortGroupName' on '$VdsName' using VLAN $VlanId" `
            -PercentComplete ([math]::Round(($RowIndex / $TotalRows) * 100))

        Write-Host ''
        Write-Host ('-' * 78) -ForegroundColor DarkCyan
        Write-Host "CONFIGURATION $RowIndex OF $TotalRows" -ForegroundColor Cyan
        Write-Host "Distributed switch : $VdsName" -ForegroundColor Cyan
        Write-Host "Port group          : $PortGroupName" -ForegroundColor Cyan
        Write-Host "Requested VLAN      : $VlanId" -ForegroundColor Cyan
        Write-Host ('-' * 78) -ForegroundColor DarkCyan

        try {
            Write-Log -Level INFO -Message "Looking for distributed switch '$VdsName'."
            $VdsMatches = @(Get-VDSwitch -Name $VdsName -Server $VIServer -ErrorAction SilentlyContinue)

            if ($VdsMatches.Count -eq 0) {
                $Statistics.SwitchesNotFound++
                $Statistics.PortGroupsNotCreated++
                $Statistics.Warnings++
                Write-Log -Level WARNING -Message "Distributed switch '$VdsName' was not found. Port group '$PortGroupName' was not processed."
                continue
            }

            if ($VdsMatches.Count -gt 1) {
                throw "More than one distributed switch named '$VdsName' was found."
            }

            $Vds = $VdsMatches[0]
            Write-Log -Level SUCCESS -Message "Found distributed switch '$VdsName'."

            $ExistingPortGroups = @(
                Get-VDPortgroup `
                    -VDSwitch $Vds `
                    -Name $PortGroupName `
                    -Server $VIServer `
                    -ErrorAction SilentlyContinue
            )

            if ($ExistingPortGroups.Count -gt 1) {
                throw "Multiple distributed port groups named '$PortGroupName' were returned on '$VdsName'."
            }

            if ($ExistingPortGroups.Count -eq 1) {
                $ExistingPortGroup = $ExistingPortGroups[0]
                $ExistingVlanId = Get-ExistingVDPortgroupVlanId -VDPortgroup $ExistingPortGroup
                $Statistics.PortGroupsExisting++
                $Statistics.Warnings++

                if ($null -eq $ExistingVlanId) {
                    $Statistics.VlanComparisonsSkipped++
                    Write-Log -Level WARNING -Message "Distributed port group '$PortGroupName' already exists on '$VdsName'. Its VLAN configuration could not be represented as a single VLAN ID, so no automatic comparison or change was made."
                }
                elseif ($ExistingVlanId -ne $VlanId) {
                    $Statistics.VlanMismatches++
                    Write-Log -Level WARNING -Message "Distributed port group '$PortGroupName' already exists on '$VdsName', but its current VLAN is '$ExistingVlanId' and the CSV requests VLAN '$VlanId'. No VLAN change was made."
                }
                else {
                    Write-Log -Level WARNING -Message "Distributed port group '$PortGroupName' already exists on '$VdsName' using VLAN '$VlanId'. No changes were required."
                }

                continue
            }

            $CreateTarget = "$VdsName / $PortGroupName"

            if ($PSCmdlet.ShouldProcess($CreateTarget, "Create distributed port group using VLAN $VlanId")) {
                $NewPortGroupParameters = @{
                    Name        = $PortGroupName
                    VDSwitch    = $Vds
                    Server      = $VIServer
                    ErrorAction = 'Stop'
                }

                if ($VlanId -gt 0) {
                    $NewPortGroupParameters.VlanId = $VlanId
                }

                New-VDPortgroup @NewPortGroupParameters | Out-Null
                $Statistics.PortGroupsCreated++
                Write-Log -Level SUCCESS -Message "Created distributed port group '$PortGroupName' on '$VdsName' using requested VLAN '$VlanId'."
            }
            else {
                $Statistics.PortGroupsNotCreated++
                Write-Log -Level WARNING -Message "Creation of distributed port group '$PortGroupName' on '$VdsName' was skipped by WhatIf or user confirmation."
            }
        }
        catch {
            $Statistics.PortGroupsNotCreated++
            $Statistics.Failures++
            Write-Log -Level ERROR -Message "Failed to process distributed port group '$PortGroupName' on '$VdsName': $($_.Exception.Message)"
        }
    }

    Write-Progress -Id 0 -Activity 'Configuring distributed port groups' -Completed

    # ========================================================================
    # SECTION 8: Completion summary
    # ========================================================================

    Show-ConsoleStep -StepNumber 6 -Title 'Displaying the completion summary'

    $SummaryLines = @(
        "CSV rows processed                : $($Statistics.RowsProcessed)",
        "Distributed port groups created   : $($Statistics.PortGroupsCreated)",
        "Distributed port groups existing  : $($Statistics.PortGroupsExisting)",
        "Distributed port groups not made  : $($Statistics.PortGroupsNotCreated)",
        "Distributed switches not found    : $($Statistics.SwitchesNotFound)",
        "VLAN mismatches                   : $($Statistics.VlanMismatches)",
        "VLAN comparisons skipped          : $($Statistics.VlanComparisonsSkipped)",
        "Warnings                          : $($Statistics.Warnings)",
        "Failures                          : $($Statistics.Failures)",
        "Log file                          : $LogPath"
    )

    Write-Host ''
    foreach ($SummaryLine in $SummaryLines) {
        Write-Host $SummaryLine
        Write-Log -Level INFO -Message $SummaryLine
    }

    if ($Statistics.Failures -eq 0) {
        Write-Log -Level SUCCESS -Message 'The script completed without processing failures.'
    }
    else {
        Write-Log -Level WARNING -Message "The script completed with $($Statistics.Failures) processing failure(s). Review the log file."
    }
}
catch {
    $FatalError = $true
    $Statistics.Failures++
    Write-Log -Level ERROR -Message "Fatal script error: $($_.Exception.Message)"
}
finally {
    Write-Progress -Id 0 -Activity 'Configuring distributed port groups' -Completed -ErrorAction SilentlyContinue

    if ($null -ne $VIServer) {
        try {
            Write-Log -Level INFO -Message "Disconnecting from vCenter '$($VIServer.Name)'."
            Disconnect-VIServer -Server $VIServer -Confirm:$false -ErrorAction Stop
            Write-Log -Level SUCCESS -Message "Disconnected from vCenter '$($VIServer.Name)'."
        }
        catch {
            Write-Log -Level WARNING -Message "An error occurred while disconnecting from vCenter: $($_.Exception.Message)"
        }
    }

    Write-Host ''
    Write-Host "Detailed log: $LogPath" -ForegroundColor Cyan

    if ($FatalError) {
        Write-Host 'The script terminated because of a fatal error. Review the log for details.' -ForegroundColor Red
    }
}
