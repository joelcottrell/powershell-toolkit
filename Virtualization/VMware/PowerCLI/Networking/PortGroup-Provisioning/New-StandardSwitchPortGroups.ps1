<#
.SYNOPSIS
    Creates VMware standard vSwitches and standard port groups on every ESXi
    host in a selected vCenter cluster.

.DESCRIPTION
    The script performs the following actions:

    1. Initializes relative paths and creates a relative Logs folder.
    2. Validates VMware PowerCLI availability.
    3. Validates and imports portgroups.csv from the project Config folder.
    4. Displays the validated CSV configuration for review.
    5. Requires Y or N confirmation before connecting to vCenter.
    6. Connects to the specified vCenter Server.
    7. Validates the selected cluster and discovers its ESXi hosts.
    8. Creates missing standard vSwitches on each eligible ESXi host.
    9. Reuses existing standard vSwitches and displays a warning.
   10. Creates missing standard port groups.
   11. Detects existing port groups and VLAN mismatches.
   12. Displays detailed nested progress bars and console step headers.
   13. Writes timestamped success, warning, and error details to a log file.
   14. Displays a completion summary and disconnects from vCenter.

.PARAMETER vCenter
    Specifies the vCenter Server FQDN or IP address. When omitted, the script
    prompts for a value.

.PARAMETER ClusterName
    Specifies the vCenter cluster to process. When omitted, the script prompts
    for a value.

.PARAMETER Credential
    Specifies credentials used to connect to vCenter. When omitted, the script
    displays a credential prompt.

.PARAMETER CsvFileName
    Specifies the CSV filename located in the project Config folder. The default value
    is portgroups.csv.

.PARAMETER Force
    Skips the interactive CSV confirmation. This is useful for an approved
    scheduled or unattended execution.

.EXAMPLE
    .\New-StandardSwitchPortGroups.ps1

.EXAMPLE
    .\New-StandardSwitchPortGroups.ps1 -vCenter "itprdvc.chboston.org" -ClusterName "Production-Cluster" -WhatIf

.EXAMPLE
    .\New-StandardSwitchPortGroups.ps1 -vCenter "itprdvc.chboston.org" -ClusterName "Production-Cluster" -Force

.NOTES
    File Name : New-StandardSwitchPortGroups.ps1
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
            - Retained detailed logging, progress bars, console headers,
              existing-object warnings, VLAN mismatch checks, and summaries.

        1.1.0 - 2026-07-21
            - Added relative-path logging and progress bars.
            - Added console step headers and existing-object warnings.
            - Added CSV validation and WhatIf support.

        1.0.0 - 2026-07-21
            - Initial script.

    Requirements:
        - Windows PowerShell 5.1 or PowerShell 7
        - VMware PowerCLI or VCF PowerCLI
        - Permissions to read clusters and ESXi hosts
        - Permissions to create standard vSwitches and port groups
        - portgroups.csv stored in the project Config folder

    Required CSV columns:
        vSwitchName
        PortGroup
        VlanID
#>

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
param (
    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$vCenter,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$ClusterName,

    [Parameter()]
    [System.Management.Automation.PSCredential]$Credential,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$CsvFileName = 'portgroups.csv',

    [Parameter()]
    [switch]$Force
)

# ============================================================================
# SECTION 1: Script initialization and relative paths
# ============================================================================

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$TotalConsoleSteps = 7
$VIServer          = $null
$FatalError        = $false
$ExecutionApproved = $false

$ScriptRoot    = $PSScriptRoot
$ProjectRoot   = $ScriptRoot
$ConfigFolder  = Join-Path -Path $ProjectRoot -ChildPath 'Config'
$CsvPath       = Join-Path -Path $ConfigFolder -ChildPath $CsvFileName
$ExampleCsvPath = Join-Path -Path $ConfigFolder -ChildPath 'portgroups.example.csv'
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
$LogPath   = Join-Path -Path $LogsFolder -ChildPath "StandardNetworkDeployment_$Timestamp.log"

$Statistics = [ordered]@{
    HostsDiscovered         = 0
    HostsProcessed          = 0
    HostsSkipped            = 0
    SwitchesCreated         = 0
    SwitchesExisting        = 0
    SwitchesNotCreated      = 0
    PortGroupsCreated       = 0
    PortGroupsExisting      = 0
    PortGroupsNotCreated    = 0
    PortGroupVlanMismatches = 0
    Warnings                = 0
    Failures                = 0
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

    $UniqueSwitches = @($CsvData | Select-Object -ExpandProperty vSwitchName -Unique)

    Write-Host ''
    Write-Host ('=' * 78) -ForegroundColor Cyan
    Write-Host 'CSV CONFIGURATION REVIEW' -ForegroundColor Cyan
    Write-Host ('=' * 78) -ForegroundColor Cyan
    Write-Host ''
    Write-Host 'I successfully read and validated the CSV file:' -ForegroundColor Green
    Write-Host "  $CsvPath" -ForegroundColor Gray
    Write-Host ''
    Write-Host "Configuration rows found : $($CsvData.Count)" -ForegroundColor Cyan
    Write-Host "Unique vSwitches found   : $($UniqueSwitches.Count)" -ForegroundColor Cyan
    Write-Host ''
    Write-Host 'The following standard network configuration will be processed:' -ForegroundColor White
    Write-Host ''

    $Preview = $CsvData |
        Sort-Object -Property vSwitchName, PortGroup |
        Select-Object `
            @{Name = 'vSwitch'; Expression = { $_.vSwitchName } }, `
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

function Update-HostProgress {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$VMHostName,

        [Parameter(Mandatory)]
        [int]$CurrentTask,

        [Parameter(Mandatory)]
        [int]$TotalTasks,

        [Parameter(Mandatory)]
        [string]$CurrentOperation
    )

    $PercentComplete = if ($TotalTasks -le 0) {
        0
    }
    else {
        [math]::Min(100, [math]::Round(($CurrentTask / $TotalTasks) * 100))
    }

    Write-Progress `
        -Id 1 `
        -ParentId 0 `
        -Activity "Processing ESXi host: $VMHostName" `
        -Status "Task $CurrentTask of $TotalTasks" `
        -CurrentOperation $CurrentOperation `
        -PercentComplete $PercentComplete
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
        'Get-Cluster',
        'Get-VMHost',
        'Get-VirtualSwitch',
        'New-VirtualSwitch',
        'Get-VirtualPortGroup',
        'New-VirtualPortGroup'
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

    $RequiredColumns = @('vSwitchName', 'PortGroup', 'VlanID')
    $AvailableColumns = @($CsvData[0].PSObject.Properties.Name)
    $MissingColumns = @($RequiredColumns | Where-Object { $_ -notin $AvailableColumns })

    if ($MissingColumns.Count -gt 0) {
        throw "The CSV is missing required columns: $($MissingColumns -join ', ')"
    }

    $CsvRowNumber = 1

    foreach ($Row in $CsvData) {
        $CsvRowNumber++
        $Row.vSwitchName = ([string]$Row.vSwitchName).Trim()
        $Row.PortGroup   = ([string]$Row.PortGroup).Trim()

        if ([string]::IsNullOrWhiteSpace($Row.vSwitchName)) {
            throw "CSV row $CsvRowNumber contains an empty vSwitchName."
        }

        if ([string]::IsNullOrWhiteSpace($Row.PortGroup)) {
            throw "CSV row $CsvRowNumber contains an empty PortGroup value."
        }

        $ParsedVlanId = 0
        $VlanIsValid = [int]::TryParse(([string]$Row.VlanID).Trim(), [ref]$ParsedVlanId)

        if (-not $VlanIsValid) {
            throw "CSV row $CsvRowNumber contains an invalid VLAN ID: '$($Row.VlanID)'"
        }

        if ($ParsedVlanId -lt 0 -or $ParsedVlanId -gt 4095) {
            throw "CSV row $CsvRowNumber contains VLAN ID '$ParsedVlanId'. The supported range is 0 through 4095."
        }

        $Row.VlanID = $ParsedVlanId
    }

    $DuplicateEntries = @(
        $CsvData |
            Group-Object -Property vSwitchName, PortGroup |
            Where-Object { $_.Count -gt 1 }
    )

    if ($DuplicateEntries.Count -gt 0) {
        throw "Duplicate vSwitch and port-group combinations were found: $($DuplicateEntries.Name -join '; ')"
    }

    $CsvSwitchGroups = @($CsvData | Group-Object -Property vSwitchName)

    Write-Log -Level SUCCESS -Message "Imported $($CsvData.Count) configuration row(s)."
    Write-Log -Level SUCCESS -Message "Identified $($CsvSwitchGroups.Count) unique standard vSwitch configuration(s)."

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
    # SECTION 7: Cluster and ESXi host discovery
    # ========================================================================

    Show-ConsoleStep -StepNumber 5 -Title 'Validating the cluster and discovering ESXi hosts'

    if ([string]::IsNullOrWhiteSpace($ClusterName)) {
        $ClusterName = (Read-Host 'What is the name of your cluster?').Trim()
    }

    if ([string]::IsNullOrWhiteSpace($ClusterName)) {
        throw 'A cluster name must be provided.'
    }

    $ClusterMatches = @(Get-Cluster -Name $ClusterName -Server $VIServer -ErrorAction SilentlyContinue)

    if ($ClusterMatches.Count -eq 0) {
        throw "Cluster '$ClusterName' was not found in vCenter '$vCenter'."
    }

    if ($ClusterMatches.Count -gt 1) {
        throw "More than one cluster named '$ClusterName' was found."
    }

    $ClusterObject = $ClusterMatches[0]
    $VMHosts = @($ClusterObject | Get-VMHost -Server $VIServer -ErrorAction Stop | Sort-Object -Property Name)

    if ($VMHosts.Count -eq 0) {
        throw "No ESXi hosts were found in cluster '$ClusterName'."
    }

    $Statistics.HostsDiscovered = $VMHosts.Count
    Write-Log -Level SUCCESS -Message "Found $($VMHosts.Count) ESXi host(s) in cluster '$ClusterName'."

    foreach ($VMHost in $VMHosts) {
        Write-Log -Level INFO -Message "Discovered ESXi host '$($VMHost.Name)' with connection state '$($VMHost.ConnectionState)'."
    }

    # ========================================================================
    # SECTION 8: Standard vSwitch and port-group processing
    # ========================================================================

    Show-ConsoleStep -StepNumber 6 -Title 'Creating and validating standard networking'

    $HostCount    = $VMHosts.Count
    $HostIndex    = 0
    $TasksPerHost = $CsvSwitchGroups.Count + $CsvData.Count

    foreach ($VMHost in $VMHosts) {
        $HostIndex++
        $HostTaskIndex = 0
        $VMHostName    = $VMHost.Name

        Write-Progress `
            -Id 0 `
            -Activity 'Configuring standard networking on ESXi hosts' `
            -Status "Host $HostIndex of ${HostCount}: $VMHostName" `
            -CurrentOperation "Beginning configuration of $VMHostName" `
            -PercentComplete ([math]::Round((($HostIndex - 1) / $HostCount) * 100))

        Write-Host ''
        Write-Host ('-' * 78) -ForegroundColor DarkCyan
        Write-Host "ESXi HOST $HostIndex OF $HostCount - $VMHostName" -ForegroundColor Cyan
        Write-Host ('-' * 78) -ForegroundColor DarkCyan
        Write-Log -Level INFO -Message "Beginning network configuration for ESXi host '$VMHostName'."

        if ($VMHost.ConnectionState -notin @('Connected', 'Maintenance')) {
            $Statistics.HostsSkipped++
            $Statistics.Warnings++
            Write-Log -Level WARNING -Message "Skipping ESXi host '$VMHostName' because its connection state is '$($VMHost.ConnectionState)'."
            Write-Progress -Id 1 -ParentId 0 -Activity "Processing ESXi host: $VMHostName" -Completed
            continue
        }

        foreach ($SwitchGroup in $CsvSwitchGroups) {
            $vSwitchName  = ([string]$SwitchGroup.Name).Trim()
            $VirtualSwitch = $null
            $HostTaskIndex++

            Update-HostProgress `
                -VMHostName $VMHostName `
                -CurrentTask $HostTaskIndex `
                -TotalTasks $TasksPerHost `
                -CurrentOperation "Checking standard vSwitch '$vSwitchName'"

            Write-Log -Level INFO -Message "Checking for standard vSwitch '$vSwitchName' on '$VMHostName'."

            try {
                $ExistingSwitches = @(
                    Get-VirtualSwitch `
                        -VMHost $VMHost `
                        -Name $vSwitchName `
                        -Standard `
                        -Server $VIServer `
                        -ErrorAction SilentlyContinue
                )

                if ($ExistingSwitches.Count -gt 1) {
                    throw "Multiple standard vSwitches named '$vSwitchName' were returned for '$VMHostName'."
                }

                if ($ExistingSwitches.Count -eq 1) {
                    $VirtualSwitch = $ExistingSwitches[0]
                    $Statistics.SwitchesExisting++
                    $Statistics.Warnings++
                    Write-Log -Level WARNING -Message "Standard vSwitch '$vSwitchName' already exists on '$VMHostName'. The existing switch will be reused for port-group processing."
                }
                else {
                    $CreateSwitchTarget = "$VMHostName / $vSwitchName"

                    if ($PSCmdlet.ShouldProcess($CreateSwitchTarget, 'Create standard vSwitch')) {
                        $VirtualSwitch = New-VirtualSwitch `
                            -VMHost $VMHost `
                            -Name $vSwitchName `
                            -Server $VIServer `
                            -ErrorAction Stop

                        $Statistics.SwitchesCreated++
                        Write-Log -Level SUCCESS -Message "Created standard vSwitch '$vSwitchName' on '$VMHostName'."
                    }
                    else {
                        $Statistics.SwitchesNotCreated++
                        Write-Log -Level WARNING -Message "Creation of standard vSwitch '$vSwitchName' on '$VMHostName' was skipped by WhatIf or user confirmation."
                    }
                }
            }
            catch {
                $Statistics.SwitchesNotCreated++
                $Statistics.Failures++
                Write-Log -Level ERROR -Message "Failed to process standard vSwitch '$vSwitchName' on '$VMHostName': $($_.Exception.Message)"
            }

            foreach ($Row in $SwitchGroup.Group) {
                $PortGroupName = ([string]$Row.PortGroup).Trim()
                $VlanId        = [int]$Row.VlanID
                $HostTaskIndex++

                Update-HostProgress `
                    -VMHostName $VMHostName `
                    -CurrentTask $HostTaskIndex `
                    -TotalTasks $TasksPerHost `
                    -CurrentOperation "Checking port group '$PortGroupName' on '$vSwitchName' using VLAN $VlanId"

                if ($null -eq $VirtualSwitch) {
                    $Statistics.PortGroupsNotCreated++
                    $Statistics.Warnings++
                    Write-Log -Level WARNING -Message "Port group '$PortGroupName' was not processed on '$VMHostName' because vSwitch '$vSwitchName' is unavailable."
                    continue
                }

                try {
                    $ExistingPortGroups = @(
                        Get-VirtualPortGroup `
                            -VirtualSwitch $VirtualSwitch `
                            -Name $PortGroupName `
                            -Server $VIServer `
                            -ErrorAction SilentlyContinue
                    )

                    if ($ExistingPortGroups.Count -gt 1) {
                        throw "Multiple port groups named '$PortGroupName' were returned on vSwitch '$vSwitchName'."
                    }

                    if ($ExistingPortGroups.Count -eq 1) {
                        $ExistingPortGroup = $ExistingPortGroups[0]
                        $ExistingVlanId    = [int]$ExistingPortGroup.VLanId
                        $Statistics.PortGroupsExisting++
                        $Statistics.Warnings++

                        if ($ExistingVlanId -ne $VlanId) {
                            $Statistics.PortGroupVlanMismatches++
                            Write-Log -Level WARNING -Message "Port group '$PortGroupName' already exists on '$VMHostName', but its current VLAN is '$ExistingVlanId' and the CSV requests VLAN '$VlanId'. No VLAN change was made."
                        }
                        else {
                            Write-Log -Level WARNING -Message "Port group '$PortGroupName' already exists on vSwitch '$vSwitchName' on '$VMHostName' using VLAN '$VlanId'. No changes were required."
                        }

                        continue
                    }

                    $CreatePortGroupTarget = "$VMHostName / $vSwitchName / $PortGroupName"

                    if ($PSCmdlet.ShouldProcess($CreatePortGroupTarget, "Create standard port group using VLAN $VlanId")) {
                        New-VirtualPortGroup `
                            -VirtualSwitch $VirtualSwitch `
                            -Name $PortGroupName `
                            -VLanId $VlanId `
                            -Server $VIServer `
                            -ErrorAction Stop |
                                Out-Null

                        $Statistics.PortGroupsCreated++
                        Write-Log -Level SUCCESS -Message "Created port group '$PortGroupName' on vSwitch '$vSwitchName' on '$VMHostName' using VLAN '$VlanId'."
                    }
                    else {
                        $Statistics.PortGroupsNotCreated++
                        Write-Log -Level WARNING -Message "Creation of port group '$PortGroupName' on '$VMHostName' was skipped by WhatIf or user confirmation."
                    }
                }
                catch {
                    $Statistics.PortGroupsNotCreated++
                    $Statistics.Failures++
                    Write-Log -Level ERROR -Message "Failed to process port group '$PortGroupName' on vSwitch '$vSwitchName' on '$VMHostName': $($_.Exception.Message)"
                }
            }
        }

        $Statistics.HostsProcessed++
        Write-Progress -Id 1 -ParentId 0 -Activity "Processing ESXi host: $VMHostName" -Completed
        Write-Progress `
            -Id 0 `
            -Activity 'Configuring standard networking on ESXi hosts' `
            -Status "Completed host $HostIndex of ${HostCount}: $VMHostName" `
            -CurrentOperation "Completed configuration of $VMHostName" `
            -PercentComplete ([math]::Round(($HostIndex / $HostCount) * 100))

        Write-Log -Level SUCCESS -Message "Completed network configuration for ESXi host '$VMHostName'."
    }

    Write-Progress -Id 1 -Activity 'Processing ESXi host' -Completed
    Write-Progress -Id 0 -Activity 'Configuring standard networking on ESXi hosts' -Completed

    # ========================================================================
    # SECTION 9: Completion summary
    # ========================================================================

    Show-ConsoleStep -StepNumber 7 -Title 'Displaying the completion summary'

    $SummaryLines = @(
        "Cluster                       : $ClusterName",
        "ESXi hosts discovered         : $($Statistics.HostsDiscovered)",
        "ESXi hosts processed          : $($Statistics.HostsProcessed)",
        "ESXi hosts skipped            : $($Statistics.HostsSkipped)",
        '',
        "vSwitches created              : $($Statistics.SwitchesCreated)",
        "vSwitches already existing     : $($Statistics.SwitchesExisting)",
        "vSwitches not created          : $($Statistics.SwitchesNotCreated)",
        '',
        "Port groups created            : $($Statistics.PortGroupsCreated)",
        "Port groups already existing   : $($Statistics.PortGroupsExisting)",
        "Port groups not created        : $($Statistics.PortGroupsNotCreated)",
        "Port-group VLAN mismatches     : $($Statistics.PortGroupVlanMismatches)",
        '',
        "Warnings                       : $($Statistics.Warnings)",
        "Failures                       : $($Statistics.Failures)",
        "Log file                       : $LogPath"
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
    Write-Progress -Id 1 -Activity 'Processing ESXi host' -Completed -ErrorAction SilentlyContinue
    Write-Progress -Id 0 -Activity 'Configuring standard networking on ESXi hosts' -Completed -ErrorAction SilentlyContinue

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
