#
# #  Run this script ONLY after successful completion of the 01-vwan.ps1 / 01-vwan.json
#
# variables in init.json file:
#   $subscriptionName: Azure subscription name
#   $rgWanName: resource group name for the virtual WAN resources
#   $hub1vpnGwName: name of the VPN gateway in the virtual hub
#   $rgBranch: resource group name for branch1 resources
#   $branch1Name: name of the branch1 VNet
#   $branch1AddressPrefix: branch1 VNet address prefix
#   $branch1subnet1Name: branch1 subnet name
#   $branch1subnet1Prefix: branch1 subnet prefix
#   $branch1gatewaysubnetPrefix: branch1 gateway subnet prefix
#   $branch1vpnGtwName: branch1 VPN gateway name
#   $branch1gtwASN: branch1 VPN gateway ASN
#   $branch1localgatewayName1: local gateway name for tunnel 1
#   $branch1localgatewayName2: local gateway name for tunnel 2
#   $branch1connectionGtwName1: branch1 connection name 1
#   $branch1connectionGtwName2: branch1 connection name 2
#   $branch1location: Azure region to deploy the branch1
#   $sharedKey: share secret of the site-to-site VPN between the branch and the hub1
#   $adminUsername: administrator username
#   $adminPassword: administrator password
#
################# Input parameters #################
param(
     [string]$initFile = 'init.json'
)
$deploymentName = (Get-Item $PSCommandPath).BaseName
$armTemplateFile = '03-vpn.json'
####################################################

$pathFiles = Split-Path -Parent $PSCommandPath
$templateFile = "$pathFiles\$armTemplateFile"
$inputParamsFile = if ([System.IO.Path]::IsPathRooted($initFile)) {
     $initFile
}
else {
     Join-Path $pathFiles $initFile
}

if (-not (Test-Path -Path $inputParamsFile -PathType Leaf)) {
     Write-Host 'parameters file not found: '$inputParamsFile -ForegroundColor Yellow
     Exit 1
}

$inputParams = Split-Path -Leaf $inputParamsFile

try {
     $arrayParams = (Get-Content -Raw $inputParamsFile | ConvertFrom-Json)
     $subscriptionName = $arrayParams.subscriptionName
     $rgWanName = $arrayParams.rgWanName
     $hub1vpnGwName = $arrayParams.hub1vpnGwName
     $rgBranch1 = $arrayParams.rgBranch
     $branch1Name = $arrayParams.branch1Name
     $branch1AddressPrefix = $arrayParams.branch1AddressPrefix
     $branch1subnet1Name = $arrayParams.branch1subnet1Name
     $branch1subnet1Prefix = $arrayParams.branch1subnet1Prefix
     $branch1gatewaysubnetPrefix = $arrayParams.branch1gatewaysubnetPrefix
     $branch1vpnGtwName = $arrayParams.branch1vpnGtwName
     $branch1gtwASN = $arrayParams.branch1gtwASN
     $branch1location = $arrayParams.branch1location
     $branch1vmName = $arrayParams.branch1vmName
     $sharedKey = $arrayParams.sharedKey
     $branch1localgatewayName1 = $arrayParams.branch1localgatewayName1
     $branch1localgatewayName2 = $arrayParams.branch1localgatewayName2
     $branch1connectionGtwName1 = $arrayParams.branch1connectionGtwName1
     $branch1connectionGtwName2 = $arrayParams.branch1connectionGtwName2
     $adminUsername = $arrayParams.adminUsername
     $adminPassword = $arrayParams.adminPassword 
}
catch {
     Write-Host 'error in reading the parameters file: '$inputParamsFile -ForegroundColor Yellow
     Exit
}

# checking the values of variables
Write-Host "$(Get-Date) - values from file: $inputParams" -ForegroundColor Yellow
if (!$subscriptionName) { Write-Host 'variable $subscriptionName is null' ; Exit }                      else { Write-Host '   subscription name.......: '$subscriptionName -ForegroundColor Yellow }
if (!$rgWanName) { Write-Host 'variable $rgWanName is null' ; Exit }                                    else { Write-Host '   resource group name.....: '$rgWanName -ForegroundColor Yellow }
if (!$hub1vpnGwName) { Write-Host 'variable $hub1vpnGwName is null' ; Exit }                            else { Write-Host '   hub1 VPN gateway name...: '$hub1vpnGwName -ForegroundColor Yellow }
if (!$rgBranch1) { Write-Host 'variable $rgBranch1 is null' ; Exit }                                    else { Write-Host '   branch1 resource group..: '$rgBranch1 -ForegroundColor Yellow }
if (!$branch1Name) { Write-Host 'variable $branch1Name is null' ; Exit }                                else { Write-Host '   branch1 name............: '$branch1Name -ForegroundColor Yellow }
if (!$branch1AddressPrefix) { Write-Host 'variable $branch1AddressPrefix is null' ; Exit }              else { Write-Host '   branch1 vnet prefix.....: '$branch1AddressPrefix -ForegroundColor Yellow }
if (!$branch1subnet1Name) { Write-Host 'variable $branch1subnet1Name is null' ; Exit }                  else { Write-Host '   branch1 subnet1 name....: '$branch1subnet1Name -ForegroundColor Yellow }
if (!$branch1subnet1Prefix) { Write-Host 'variable $branch1subnet1Prefix is null' ; Exit }              else { Write-Host '   branch1 subnet1 prefix..: '$branch1subnet1Prefix -ForegroundColor Yellow }
if (!$branch1gatewaysubnetPrefix) { Write-Host 'variable $branch1gatewaysubnetPrefix is null' ; Exit }  else { Write-Host '   branch1 gw subnet prefix: '$branch1gatewaysubnetPrefix -ForegroundColor Yellow }
if (!$branch1vpnGtwName) { Write-Host 'variable $branch1vpnGtwName is null' ; Exit }                    else { Write-Host '   branch1 VPN gateway name: '$branch1vpnGtwName -ForegroundColor Yellow }
if (!$branch1gtwASN) { Write-Host 'variable $branch1gtwASN is null' ; Exit }                            else { Write-Host '   branch1 gateway ASN.....: '$branch1gtwASN -ForegroundColor Yellow }
if (!$branch1location) { Write-Host 'variable $branch1location is null' ; Exit }                        else { Write-Host '   branch1 location........: '$branch1location -ForegroundColor Yellow }
if (!$branch1vmName) { Write-Host 'variable $branch1vmName is null' ; Exit }                            else { Write-Host '   branch1 VM name.........: '$branch1vmName -ForegroundColor Yellow }
if (!$sharedKey) { Write-Host 'variable $sharedKey is null' ; Exit }                                    else { Write-Host '   shared key..............: '$sharedKey -ForegroundColor Yellow }
if (!$branch1localgatewayName1) { Write-Host 'variable $branch1localgatewayName1 is null' ; Exit }      else { Write-Host '   local gateway 1 name....: '$branch1localgatewayName1 -ForegroundColor Yellow }
if (!$branch1localgatewayName2) { Write-Host 'variable $branch1localgatewayName2 is null' ; Exit }      else { Write-Host '   local gateway 2 name....: '$branch1localgatewayName2 -ForegroundColor Yellow }
if (!$branch1connectionGtwName1) { Write-Host 'variable $branch1connectionGtwName1 is null' ; Exit }    else { Write-Host '   connection 1 name.......: '$branch1connectionGtwName1 -ForegroundColor Yellow }
if (!$branch1connectionGtwName2) { Write-Host 'variable $branch1connectionGtwName2 is null' ; Exit }    else { Write-Host '   connection 2 name.......: '$branch1connectionGtwName2 -ForegroundColor Yellow }
if (!$adminUsername) { Write-Host 'variable $adminUsername is null' ; Exit }                            else { Write-Host '   administrator username..: '$adminUsername -ForegroundColor Green }
if (!$adminPassword) { Write-Host 'variable $adminPassword is null' ; Exit }                            else { Write-Host '   administrator password..: '$adminPassword -ForegroundColor Green }

# Login Check
Try {Write-Host 'Using Subscription: ' -NoNewline
     Write-Host $((Get-AzContext).Name) -ForegroundColor Green}
Catch {
    Write-Warning 'You are not logged in dummy. Login and try again!'
    Return}

$subscr = Get-AzSubscription -SubscriptionName $subscriptionName
Select-AzSubscription -SubscriptionId $subscr.Id


try {
     # check if exists the VPN GTW for site-to-site in vWAN
     # if it exists, the flag $deployVPNGtwS2S is set to false avoiding the reset of S2S VPN Gateway configuration
     write-host "$(Get-Date) - check if exists the S2S VPN GTW in vWAN: "$hub1vpnGwName -ForegroundColor Cyan
     $hub1vpnGateway = Get-AzVpnGateway -ResourceGroupName $rgWanName -Name $hub1vpnGwName -ErrorAction Stop
}
catch {
     write-host "$(Get-Date) - S2S VPN GTW in vWAN: $hub1vpnGwName does not exist" -ForegroundColor Cyan
     Exit
}
#getting IPs VPNGTW1

$hub1vpn_PublicIP1 = Out-String -InputObject ($hub1vpnGateway.IpConfigurations.PublicIpAddress[0]) -NoNewline
$hub1vpn_PublicIP2 = Out-String -InputObject ($hub1vpnGateway.IpConfigurations.PublicIpAddress[1]) -NoNewline
$hub1vpn_BGPIP1 = Out-String -InputObject ($hub1vpnGateway.BgpSettings.BgpPeeringAddresses[0].DefaultBgpIpAddresses) -NoNewline
$hub1vpn_BGPIP2 = Out-String -InputObject ($hub1vpnGateway.BgpSettings.BgpPeeringAddresses[1].DefaultBgpIpAddresses) -NoNewline

if (!$hub1vpn_PublicIP1) { Write-Host 'variable $hub1vpn_PublicIP1 is null' ; Exit } else { Write-Host '  vpn-hub1 public IP1: '$hub1vpn_PublicIP1 -ForegroundColor Green}
if (!$hub1vpn_PublicIP2) { Write-Host 'variable $hub1vpn_PublicIP2 is null' ; Exit } else { Write-Host '  vpn-hub1 public IP2: '$hub1vpn_PublicIP2 -ForegroundColor Green}
if (!$hub1vpn_BGPIP1) { Write-Host 'variable $hub1vpn_BGPIP1 is null' ; Exit }       else { Write-Host '  vpn-hub1 BGP IP1...: '$hub1vpn_BGPIP1 -ForegroundColor Green}
if (!$hub1vpn_BGPIP2) { Write-Host 'variable $hub1vpn_BGPIP2 is null' ; Exit }       else { Write-Host '  vpn-hub1 BGP IP2...: '$hub1vpn_BGPIP2 -ForegroundColor Green}

########

$parameters=@{
              "branch1Name" = $branch1Name;
              "branch1AddressPrefix" = $branch1AddressPrefix;
              "branch1subnet1Name" = $branch1subnet1Name;
              "branch1subnet1Prefix" = $branch1subnet1Prefix;
              "branch1gatewaysubnetPrefix" = $branch1gatewaysubnetPrefix;
              "branch1location" = $branch1location;
              "branch1vmName" = $branch1vmName;
              "branch1gtwASN" = $branch1gtwASN;
              "branch1localgatewayName1" = $branch1localgatewayName1;
              "branch1localgatewayName2" = $branch1localgatewayName2;
              "branch1connectionGtwName1" = $branch1connectionGtwName1;
              "branch1connectionGtwName2" = $branch1connectionGtwName2;
              "branch1vpnGtwName" = $branch1vpnGtwName;
              "sharedKey" = $sharedKey;
              "hub1vpn_PublicIP1" = $hub1vpn_PublicIP1;
              "hub1vpn_PublicIP2" = $hub1vpn_PublicIP2;
              "hub1vpn_BGPIP1" = $hub1vpn_BGPIP1;
              "hub1vpn_BGPIP2" = $hub1vpn_BGPIP2;
              "adminUsername" = $adminUsername;
              "adminPassword" = $adminPassword
              }


$location=$branch1location             
# Create Resource Group
Write-Host "$(Get-Date) - Creating Resource Group: $rgBranch1" -ForegroundColor Cyan
Try { Get-AzResourceGroup -Name $rgBranch1 -ErrorAction Stop
     Write-Host 'Resource exists, skipping'}
Catch { 
     New-AzResourceGroup -Name $rgBranch1 -Location $location
     Write-Host "$(Get-Date) - Resource group created: "$rgBranch1 -ForegroundColor Green
     # Set tag on the resource group
     Set-AzResourceGroup -Name $rgBranch1 -Tag @{"PM owner" = "fabferri"; "Project" = "vWAN validation" }
}


$startTime = Get-Date
write-host "$(Get-Date) - running ARM template: "$templateFile
New-AzResourceGroupDeployment  -Name $deploymentName -ResourceGroupName $rgBranch1 -TemplateFile $templateFile -TemplateParameterObject $parameters -Verbose 
 
Write-Host "$(Get-Date) - setup completed" -ForegroundColor Green
$endTime = Get-Date
$timeDiff = New-TimeSpan $startTime $endTime
$mins = $timeDiff.Minutes
$secs = $timeDiff.Seconds
$runTime = '{0:00}:{1:00} (M:S)' -f $mins, $secs

Write-Host "$(Get-Date) - Script completed" -ForegroundColor Green
Write-Host "Time to complete: "$runTime







