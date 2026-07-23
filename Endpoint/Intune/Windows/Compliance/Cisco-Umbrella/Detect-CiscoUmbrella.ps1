<#	
.NOTES
	Name: Detect-Cisco-Umbrella-v1.ps1 
	Author: Joel Cottrell
	Copyright: GPLv3
	Tags: intune endpoint MEM cisco umbrella

.LICENSEURI
https://github.com/bigjoestretch/public/blob/main/LICENSE

.PROJECTURI
https://github.com/bigjoestretch/public/blob/main/Intune/Windows/Compliance/Cisco%20Umbrella

.ICONURI

.EXTERNALMODULEDEPENDENCIES

.REQUIREDSCRIPTS 

.EXTERNALSCRIPTDEPENDENCIES

.RELEASENOTES
v1.0 - 24/09/23 - Initial release of this script.
	
.SYNOPSIS
Custom compliance script to report Cisco Umbrella Client service state and startup configuration

.DESCRIPTION
This script checks the Cisco Umbrella Client service Startup Type and Service state. The service must be 'running' and startup must be set to 'Automatic'
    
.EXAMPLE
Example output: {"ServiceState":4,"ServiceStartupMode":3}

#>

$ServiceState = get-service -name "csc_umbrellaagent" | Select-object Status
$ServiceStartupMode = get-service -name "csc_umbrellaagent" | Select-object StartType

$output = @{
	ServiceState = $ServiceState.Status
	ServiceStartupMode = $ServiceStartupMode.StartType
}

return $output | ConvertTo-Json -Compress

# This section below should be saved As a JSON file and added/imported to an Intune Custom Compliance policy):
#{
#    "Rules":[ 
#        { 
#           "SettingName":"ServiceState",
#           "Operator":"IsEquals",
#           "DataType":"Int64",
#           "Operand":4,
#           "MoreInfoUrl":"https://docs.umbrella.com/deployment-umbrella/docs/appx-c-troubleshooting",
#           "RemediationStrings":[ 
#              { 
#                 "Language": "en_US",
#                 "Title": "The Cisco Secure Client service must be running. Value discovered was {ActualValue}.",
#                 "Description": "Your device must have the Cisco Umbrella client running and enabled. Try restarting your device, and then follow the steps here: https://docs.umbrella.com/deployment-umbrella/docs/appx-c-troubleshooting. If you do this and get this message again, contact Corporate IT at itsupport@intelycare.com."
#              }
#           ]
#        },
#        { 
#         "SettingName":"ServiceStartupMode",
#         "Operator":"IsEquals",
#         "DataType":"Int64",
#         "Operand":3,
#         "MoreInfoUrl":"https://docs.umbrella.com/deployment-umbrella/docs/appx-c-troubleshooting",
#         "RemediationStrings":[ 
#            { 
#               "Language": "en_US",
#               "Title": "The Cisco Secure Client service startup must be set to Manual. Value discovered was {ActualValue}.",
#               "Description": "Your device must have the Cisco Umbrella client running and enabled. Try restarting your device, and then follow the steps here: https://docs.umbrella.com/deployment-umbrella/docs/appx-c-troubleshooting. If you do this and get this message again, contact Corporate IT at itsupport@intelycare.com."
#            }
#         ]
#      }
#     ]
#    }
