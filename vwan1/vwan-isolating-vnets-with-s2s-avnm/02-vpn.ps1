# This script deploys the VPN Gateways in the virtual hubs in vWAN
#  variables in init.json file:
#   $adminUsername: administrator username
#   $adminPassword: administrator password
#   $subscriptionName: Azure subscription name
#   $ResourceGroupName: resource group name
#   $hub1location: Azure region to deploy the virtual hub1
#   $hub2location: Azure region to deploy the virtual hub2
#   $branch1location: Azure region to deploy the branch1
#   $branch2location: Azure region to deploy the branch2
#   $hub1Name: name of the virtual hub1
#   $hub2Name: name of the virtual hub2 
#   $sharedKey: Share secret of the site-to-site VPN
#
################# Input parameters #################
$deploymentName = 'vpn-branches'
$armTemplateFile = '02-vpn.json'
$initFile = 'init.json'

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
     $ResourceGroupName = $arrayParams.ResourceGroupName
     $hub1location = $arrayParams.hub1location
     $hub2location = $arrayParams.hub2location
     $branch1location = $arrayParams.branch1location
     $branch2location = $arrayParams.branch2location
     $hub1Name = $arrayParams.hub1Name
     $hub2Name = $arrayParams.hub2Name
     $sharedKey = $arrayParams.sharedKey
     $adminUsername = $arrayParams.adminUsername
     $adminPassword = $arrayParams.adminPassword
}
catch {
     Write-Host 'error in reading the parameters file: '$inputParamsFile -ForegroundColor Yellow
     Exit
}

# checking the values of variables
Write-Host "$(Get-Date) - values from file: $inputParams" -ForegroundColor Yellow
if (!$subscriptionName) { Write-Host 'variable $subscriptionName is null' ; Exit }      else { Write-Host '   subscription name......: '$subscriptionName -ForegroundColor Yellow }
if (!$ResourceGroupName) { Write-Host 'variable $ResourceGroupName is null' ; Exit }    else { Write-Host '   resource group name....: '$ResourceGroupName -ForegroundColor Yellow }
if (!$hub1location) { Write-Host 'variable $hub1location is null' ; Exit }              else { Write-Host '   hub1 location.....   ..: '$hub1location -ForegroundColor Yellow }
if (!$hub2location) { Write-Host 'variable $hub2location is null' ; Exit }              else { Write-Host '   hub2 location....   ...: '$hub2location -ForegroundColor Yellow }
if (!$branch1location) { Write-Host 'variable $branch1location is null' ; Exit }        else { Write-Host '   branch1 location.......: '$branch1location -ForegroundColor Yellow }
if (!$branch2location) { Write-Host 'variable $branch2location is null' ; Exit }        else { Write-Host '   branch2 location.......: '$branch2location -ForegroundColor Yellow }
if (!$hub1Name) { Write-Host 'variable $hub1Name is null' ; Exit }                      else { Write-Host '   hub1 name..............: '$hub1Name -ForegroundColor Yellow }
if (!$hub2Name) { Write-Host 'variable $hub2Name is null' ; Exit }                      else { Write-Host '   hub2 name.......: '$hub2Name -ForegroundColor Yellow }
if (!$sharedKey) { Write-Host 'variable $sharedKey is null' ; Exit }                    else { Write-Host '   shared key.............: '$sharedKey -ForegroundColor Yellow }
if (!$adminUsername) { Write-Host 'variable $adminUsername is null' ; Exit }            else { Write-Host '   administrator username.: '$adminUsername -ForegroundColor Green }
if (!$adminPassword) { Write-Host 'variable $adminPassword is null' ; Exit }            else { Write-Host '   administrator password.: '$adminPassword -ForegroundColor Green }

$rgName=$ResourceGroupName

$subscr=Get-AzSubscription -SubscriptionName $subscriptionName
Select-AzSubscription -SubscriptionId $subscr.Id

# Login Check
Try {Write-Host 'Using Subscription: ' -NoNewline
     Write-Host $((Get-AzContext).Name) -ForegroundColor Green}
Catch {
    Write-Warning 'You are not logged in dummy. Login and try again!'
    Return}

# VPN GTW for site-to-site in vWAN
$hub1vpnGtwName=$hub1Name+'_gw'
$hub1vpnGateway = Get-AzVpnGateway -ResourceGroupName $rgName -Name $hub1vpnGtwName

#getting IPs VPNGTW1
$hub1vpn_PublicIP1= Out-String -InputObject ($hub1vpnGateway.IpConfigurations.PublicIpAddress[0]) -NoNewline
$hub1vpn_PublicIP2= Out-String -InputObject ($hub1vpnGateway.IpConfigurations.PublicIpAddress[1]) -NoNewline
$hub1vpn_BGPIP1= Out-String -InputObject ($hub1vpnGateway.BgpSettings.BgpPeeringAddresses[0].DefaultBgpIpAddresses) -NoNewline
$hub1vpn_BGPIP2= Out-String -InputObject ($hub1vpnGateway.BgpSettings.BgpPeeringAddresses[1].DefaultBgpIpAddresses) -NoNewline

if (!$hub1vpn_PublicIP1) { Write-Host 'variable $hub1vpn_PublicIP1 is null' ; Exit } else { Write-Host '   vpn-hub1 public IP1: '$hub1vpn_PublicIP1 -ForegroundColor Green}
if (!$hub1vpn_PublicIP2) { Write-Host 'variable $hub1vpn_PublicIP2 is null' ; Exit } else { Write-Host '   vpn-hub1 public IP2: '$hub1vpn_PublicIP2 -ForegroundColor Green}
if (!$hub1vpn_BGPIP1) { Write-Host 'variable $hub1vpn_BGPIP1 is null' ; Exit } else { Write-Host '   vpn-hub1 BGP IP1...: '$hub1vpn_BGPIP1 -ForegroundColor Green}
if (!$hub1vpn_BGPIP2) { Write-Host 'variable $hub1vpn_BGPIP2 is null' ; Exit } else { Write-Host '   vpn-hub1 BGP IP2...: '$hub1vpn_BGPIP2 -ForegroundColor Green}

########
# VPN GTW for site-to-site in vWAN
$hub2vpnGtwName=$hub2Name+'_gw'
$hub2vpnGateway = Get-AzVpnGateway -ResourceGroupName $rgName -Name $hub2vpnGtwName

#getting IPs VPNGTW2
$hub2vpn_PublicIP1= Out-String -InputObject ($hub2vpnGateway.IpConfigurations.PublicIpAddress[0]) -NoNewline
$hub2vpn_PublicIP2= Out-String -InputObject ($hub2vpnGateway.IpConfigurations.PublicIpAddress[1]) -NoNewline
$hub2vpn_BGPIP1= Out-String -InputObject ($hub2vpnGateway.BgpSettings.BgpPeeringAddresses[0].DefaultBgpIpAddresses) -NoNewline
$hub2vpn_BGPIP2= Out-String -InputObject ($hub2vpnGateway.BgpSettings.BgpPeeringAddresses[1].DefaultBgpIpAddresses) -NoNewline

if (!$hub2vpn_PublicIP1) { Write-Host 'variable $hub2vpn_PublicIP1 is null' ; Exit } else { Write-Host '   vpn-hub2 public IP1: '$hub2vpn_PublicIP1 -ForegroundColor Cyan}
if (!$hub2vpn_PublicIP2) { Write-Host 'variable $hub2vpn_PublicIP2 is null' ; Exit } else { Write-Host '   vpn-hub2 public IP2: '$hub2vpn_PublicIP2 -ForegroundColor Cyan}
if (!$hub2vpn_BGPIP1) { Write-Host 'variable $hub2vpn_BGPIP1 is null' ; Exit } else { Write-Host '   vpn-hub2 BGP IP1...: '$hub2vpn_BGPIP1 -ForegroundColor Cyan}
if (!$hub2vpn_BGPIP2) { Write-Host 'variable $hub2vpn_BGPIP2 is null' ; Exit } else { Write-Host '   vpn-hub2 BGP IP2...: '$hub2vpn_BGPIP2 -ForegroundColor Cyan}



$parameters=@{
              "branch1location"= $branch1location;
              "branch2location"= $branch2location;
              "hub1vpn_PublicIP1" = $hub1vpn_PublicIP1;
              "hub1vpn_PublicIP2" = $hub1vpn_PublicIP2;
              "hub1vpn_BGPIP1" = $hub1vpn_BGPIP1;
              "hub1vpn_BGPIP2" = $hub1vpn_BGPIP2;
              "hub2vpn_PublicIP1" = $hub2vpn_PublicIP1;
              "hub2vpn_PublicIP2" = $hub2vpn_PublicIP2;
              "hub2vpn_BGPIP1" = $hub2vpn_BGPIP1;
              "hub2vpn_BGPIP2" = $hub2vpn_BGPIP2;
              "sharedKey" = $sharedKey;
              "adminUsername" = $adminUsername;
              "adminPassword" = $adminPassword
              }


$location=$hub1location

# Create Resource Group
Write-Host "$(Get-Date) - creating Resource Group: "$rgName -ForegroundColor Cyan
Try {
     $rg = Get-AzResourceGroup -Name $rgName -ErrorAction Stop
     Write-Host "$(Get-Date) - Resource Group exists, skipping" -ForegroundColor Yellow
}
Catch { 
     $rg = New-AzResourceGroup -Name $rgName -Location $location 
     Write-Host "$(Get-Date) - Resource group created: "$rg.ResourceGroupName -ForegroundColor Green
     # Set tag on the resource group
     Set-AzResourceGroup -Name $rgName -Tag @{"owner" = "fabferri"; "Project" = "validation avnm+vWAN" }
}

$startTime = Get-Date
write-host "$(Get-Date) - running ARM template:"$templateFile -ForegroundColor Cyan
New-AzResourceGroupDeployment  -Name $deploymentName -ResourceGroupName $rgName -TemplateFile $templateFile -TemplateParameterObject $parameters -Verbose 

Write-Host "$(Get-Date) - setup completed" -ForegroundColor Green
$endTime = Get-Date
$timeDiff = New-TimeSpan $startTime $endTime
$mins = $timeDiff.Minutes
$secs = $timeDiff.Seconds
$runTime = '{0:00}:{1:00} (M:S)' -f $mins, $secs
Write-Host "$(Get-Date) - Script completed" -ForegroundColor Green
Write-Host "Time to complete: "$runTime -ForegroundColor Green

