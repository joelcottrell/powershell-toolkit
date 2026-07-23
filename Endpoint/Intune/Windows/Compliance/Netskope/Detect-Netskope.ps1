<#	
.NOTES
	Name: Detect-Netskope.ps1 
	Author: Joel Cottrell
	Copyright: GPLv3
	Tags: intune endpoint MEM netskope

.LICENSEURI
https://github.com/bigjoestretch/public/blob/main/LICENSE

.PROJECTURI
https://github.com/bigjoestretch/public/blob/main/Intune/Windows/Compliance/Netskope

.ICONURI

.EXTERNALMODULEDEPENDENCIES

.REQUIREDSCRIPTS 

.EXTERNALSCRIPTDEPENDENCIES

.RELEASENOTES
v1.0 - 24/09/23 - Initial release of this script.
	
.SYNOPSIS
Custom compliance script to report Netskope Client service state and startup configuration

.DESCRIPTION
This script checks the Netskope Client service Startup Type and Service state. The service must be 'running' and startup must be set to 'Automatic'
    
.EXAMPLE
Example output: {"ServiceState":4,"ServiceStartupMode":2}

#>

$ServiceState = get-service -name "stAgentSvc" | Select-object Status
$ServiceStartupMode = get-service -name "stAgentSvc" | Select-object StartType

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
#           "MoreInfoUrl":"https://docs.netskope.com/en/netskope-client-troubleshooting-guide/",
#           "RemediationStrings":[ 
#              { 
#                 "Language": "en_US",
#                 "Title": "The Netskope client service must be running. Value discovered was {ActualValue}.",
#                 "Description": "Your device must have the Netskope client service running and enabled. Try restarting your device, and then follow the steps here: https://docs.netskope.com/en/netskope-client-troubleshooting-guide/. If you do this and get this message again, contact Corporate IT at itsupport@intelycare.com."
#              }
#           ]
#        },
#        { 
#         "SettingName":"ServiceStartupMode",
#         "Operator":"IsEquals",
#         "DataType":"Int64",
#         "Operand":2,
#         "MoreInfoUrl":"https://docs.netskope.com/en/netskope-client-troubleshooting-guide/",
#         "RemediationStrings":[ 
#            { 
#               "Language": "en_US",
#               "Title": "The Netskope client service startup must be set to Automatic. Value discovered was {ActualValue}.",
#               "Description": "Your device must have the Netskope client service startup set to Automatic. Try restarting your device, and then follow the steps here: https://docs.netskope.com/en/netskope-client-troubleshooting-guide/. If you do this and get this message again, contact Corporate IT at itsupport@intelycare.com."
#            }
#         ]
#      }
#     ]
#    }
