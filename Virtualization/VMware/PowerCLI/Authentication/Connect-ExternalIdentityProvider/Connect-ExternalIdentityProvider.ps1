<#	
.NOTES
	Name: powercli_entra_id_connect_vcenter.ps1
	Author: Joel Cottrell
	Copyright: GPLv3
	Tags: vsphere

.LICENSEURI
https://github.com/bigjoestretch/public/blob/main/LICENSE

.PROJECTURI
https://github.com/bigjoestretch/public/tree/main/VMWare/PowerCLI/Connect%20to%20External%20Identity%20Provider/Entra%20ID

.ICONURI

.EXTERNALMODULEDEPENDENCIES

.REQUIREDSCRIPTS 

.EXTERNALSCRIPTDEPENDENCIES

.RELEASENOTES
v1.0 - 25/05/13 - Initial release of this script.
	
.SYNOPSIS
Use VMWare PowerCLI with Microsoft Entra ID Federated vCenter Logins

.DESCRIPTION
This script allows you to use VMWare PowerCLI with Microsoft Entra ID Federated vCenter Logins.

.EXAMPLE
Example output:

Name                           Port  User
----                           ----  ----
test.testing.org               443   TESTING.ORG\test01…

#>

# Define the vCenter Server URL 				#e.g. $vCenterServer = "https://<Your_vCenter_Server_FQDN>"
$vCenterServer = "<Your_vCenter_Server_FQDN"

# Create a new OAuth2 client

$newOAuthArguments = @{
  ClientID     = 'powercli-native'
  Name         = 'PowerCLI Client'
  Scope        = @("admin", "user", "profile", "email", "openid", "group")
  GrantTypes   = @("authorization_code", "refresh_token")
  RedirectUris = @("http://localhost:8844/authcode")
  PkceEnforced = $true
  AccessTokenTimeToLiveMinutes      = 30
  RefreshTokenTimeToLiveMinutes     = 43200
  RefreshTokenIdleTimeToLiveMinutes = 28800
}
$newClient = New-VIOAuth2Client @newOAuthArguments

# NOTE: Use $newClient.secret to view the new secret if needed.

#$ClientSecret = $newClient.secret

# Use the values above to login to vCenter Server using PowerCLI.

$newOAuthArguments = @{
  TokenEndpointUrl         = 'https://$vCenterServer/acs/t/CUSTOMER/token'
  AuthorizationEndpointUrl = 'https://$vCenterServer/acs/t/CUSTOMER/authorize' 
  RedirectUrl              = 'http://localhost:8844/authcode'
  ClientId                 = '$newClient.ClientID'
  ClientSecret             = '$newClient.secret'
}

$oauthSecContext = New-OAuthSecurityContext @newOAuthArguments

# The default web browser should open to an Azure / Entra AD login page. You should be redirected after entering your credentials.

# Take the $ouathSecContext return from the previous codeblock and use it to create a $samlSecContext and use that to connect to our vCenter.

$samlSecContext = New-VISamlSecurityContext -VCenterServer '$vCenterServer' -OAuthSecurityContext $oauthSecContext

# Connect to vCenter

Connect-VIServer -Server '$vCenterServer' -SamlSecurityContext $samlSecContext

<# The above commands will return a successful login prompt:

Name                           Port  User
----                           ----  ----
test.testing.org               443   TESTING.ORG\test01…
#>
