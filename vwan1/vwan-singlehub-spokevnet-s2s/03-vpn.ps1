#
# #  Run this script ONLY after successful completion of the 01-vwan.ps1 / 01-vwan.json
#
# variables in init.json file:
#   $subscriptionName: Azure subscription name
#   $ResourceGroupName: resource group name
#   $hub1location: Azure region to deploy the virtual hub1
#   $hub1Name: name of the virtual hub1
#   $branch1location: Azure region to deploy the branch1
#   $sharedKey: share secret of the site-to-site VPN between the branch and the hub1
#   $adminUsername: administrator username
#   $adminPassword: administrator password
#   $mngIP: public IP to filter inbound SSH connection to the VMs. it can be empty if you do not want to set a restriction.
#
################# Input parameters #################
$deploymentName = 'vpn-branches'
$armTemplateFile = '03-vpn.json'
$inputParams = 'init.json'
####################################################

$pathFiles = Split-Path -Parent $PSCommandPath
$templateFile = "$pathFiles\$armTemplateFile"
$inputParamsFile = "$pathFiles\$inputParams"

try {
     $arrayParams = (Get-Content -Raw $inputParamsFile | ConvertFrom-Json)
     $subscriptionName = $arrayParams.subscriptionName
     $rgName = $arrayParams.rgName
     $location = $arrayParams.location
     $vwanName = $arrayParams.vwanName
     $hub1location = $arrayParams.hub1location
     $hub1Name = $arrayParams.hub1Name
     $rgSpoke21 = $arrayParams.rgSpoke21
     $spoke21location = $arrayParams.spoke21location
     $rgSpoke22 = $arrayParams.rgSpoke22
     $spoke22location = $arrayParams.spoke22location
     $adminUsername = $arrayParams.adminUsername
     $adminPassword = $arrayParams.adminPassword 
     $branch1location = $arrayParams.branch1location
     $sharedKey = $arrayParams.sharedKey
     $hub1vpnGwName = $arrayParams.hub1vpnGwName
     $rgBranch1 = $arrayParams.rgBranch1
     $branch1vpnGtwName = $arrayParams.branch1vpnGtwName
}
catch {
     Write-Host 'error in reading the parameters file: '$inputParamsFile -ForegroundColor Yellow
     Exit
}

# checking the values of variables
Write-Host "$(Get-Date) - values from file: $inputParams" -ForegroundColor Yellow
if (!$subscriptionName) { Write-Host 'variable $subscriptionName is null' ; Exit }   else { Write-Host '   subscription name.......: '$subscriptionName -ForegroundColor Yellow }
if (!$adminUsername) { Write-Host 'variable $adminUsername is null' ; Exit }         else { Write-Host '   administrator username..: '$adminUsername -ForegroundColor Green }
if (!$adminPassword) { Write-Host 'variable $adminPassword is null' ; Exit }         else { Write-Host '   administrator password..: '$adminPassword -ForegroundColor Green }
if (!$location) { Write-Host 'variable $location is null' ; Exit }                   else { Write-Host '   location................: '$location -ForegroundColor Yellow }
if (!$hub1Name) { Write-Host 'variable $hub1Name is null' ; Exit }                   else { Write-Host '   hub1 name...............: '$hub1Name -ForegroundColor Yellow }
if (!$hub1location) { Write-Host 'variable $hub1location is null' ; Exit }           else { Write-Host '   hub1 location...........: '$hub1location -ForegroundColor Yellow }
if (!$vwanName) { Write-Host 'variable $vwanName is null' ; Exit }                   else { Write-Host '   vwan name...............: '$vwanName -ForegroundColor Yellow }
if (!$spoke21location) { Write-Host 'variable $spoke21location is null' ; Exit }     else { Write-Host '   spoke21 location........: '$spoke21location -ForegroundColor Yellow }
if (!$spoke22location) { Write-Host 'variable $spoke22location is null' ; Exit }     else { Write-Host '   spoke22 location........: '$spoke22location -ForegroundColor Yellow }
if (!$rgName) { Write-Host 'variable $rgName is null' ; Exit }                       else { Write-Host '   resource group name.....: '$rgName -ForegroundColor Yellow }
if (!$rgSpoke21) { Write-Host 'variable $rgSpoke21 is null' ; Exit }                 else { Write-Host '   spoke21 resource group..: '$rgSpoke21 -ForegroundColor Yellow }
if (!$rgSpoke22) { Write-Host 'variable $rgSpoke22 is null' ; Exit }                 else { Write-Host '   spoke22 resource group..: '$rgSpoke22 -ForegroundColor Yellow }
if (!$hub1vpnGwName) { Write-Host 'variable $hub1vpnGwName is null' ; Exit }         else { Write-Host '   hub1 VPN gateway name...: '$hub1vpnGwName -ForegroundColor Yellow }
if (!$sharedKey) { Write-Host 'variable $sharedKey is null' ; Exit }                 else { Write-Host '   shared key..............: '$sharedKey -ForegroundColor Yellow }
if (!$branch1location) { Write-Host 'variable $branch1location is null' ; Exit }     else { Write-Host '   branch1 location........: '$branch1location -ForegroundColor Yellow }
if (!$branch1vpnGtwName) { Write-Host 'variable $branch1vpnGtwName is null' ; Exit } else { Write-Host '   branch1 VPN gateway name: '$branch1vpnGtwName -ForegroundColor Yellow }
if (!$rgBranch1) { Write-Host 'variable $rgBranch1 is null' ; Exit }                 else { Write-Host '   branch1 resource group..: '$rgBranch1 -ForegroundColor Yellow }

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
     write-host "$(Get-Date) - check if exists the S2S VPN GTW in vWAN: "$hub1vpnGtwName -ForegroundColor Cyan
     $hub1vpnGateway = Get-AzVpnGateway -ResourceGroupName $rgName -Name $hub1vpnGtwName -ErrorAction Stop
}
catch {
     write-host "$(Get-Date) - S2S VPN GTW in vWAN: $hub1vpnGtwName does not exist" -ForegroundColor Cyan
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
              "branch1location"= $branch1location;
              "branch1vpnGtwName"= $branch1vpnGtwName;
              "sharedKey"= $sharedKey;
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
Catch { New-AzResourceGroup -Name $rgBranch1 -Location $location}


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







