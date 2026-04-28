#
#  variables in init.json file:
#   $subscriptionName: Azure subscription name
#   $rgWanName: resource group name for the virtual WAN resources
#   $vwanName: name of the virtual WAN
#   $hub1location: Azure region for the virtual hub
#   $hub1Name: name of the virtual hub
#   $rgSpoke21: resource group name for spoke21
#   $spoke21vnetName: name of the spoke21 virtual network
#   $spoke21location: Azure region for spoke21 resources
#   $spoke21AddressPrefix: address prefix for spoke21
#   $spoke21subnetFEName: front-end subnet name in spoke21
#   $spoke21subnetFEPrefix: front-end subnet prefix in spoke21
#   $spoke21subnetBEName: back-end subnet name in spoke21
#   $spoke21subnetBEPrefix: back-end subnet prefix in spoke21
#   $spoke21subnetWLName: workload subnet name in spoke21
#   $spoke21subnetWLPrefix: workload subnet prefix in spoke21
#   $spoke21BAddressPrefix: address prefix for child spoke21B
#   $spoke21lbFrontEndIP: load balancer frontend IP for spoke21
#   $rgSpoke22: resource group name for spoke22
#   $spoke22vnetName: name of the spoke22 virtual network
#   $spoke22location: Azure region for spoke22 resources
#   $spoke22AddressPrefix: address prefix for spoke22
#   $spoke22subnetFEName: front-end subnet name in spoke22
#   $spoke22subnetFEPrefix: front-end subnet prefix in spoke22
#   $spoke22subnetBEName: back-end subnet name in spoke22
#   $spoke22subnetBEPrefix: back-end subnet prefix in spoke22
#   $spoke22subnetWLName: workload subnet name in spoke22
#   $spoke22subnetWLPrefix: workload subnet prefix in spoke22
#   $spoke22BAddressPrefix: address prefix for child spoke22B
#   $spoke22lbFrontEndIP: load balancer frontend IP for spoke22
#   $hub1vpnGwName: name of the hub VPN gateway
#
################# Input parameters #################
param(
     [string]$initFile = 'init.json'
)
$deploymentName = (Get-Item $PSCommandPath).BaseName
$armTemplateFile = '02-vwan.json'
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
     $vwanName = $arrayParams.vwanName
     $hub1Name = $arrayParams.hub1Name
     $hub1location = $arrayParams.hub1location
     $hub1addressPrefix = $arrayParams.hub1addressPrefix
     $hub1vpnGwName = $arrayParams.hub1vpnGwName
     $rgSpoke21 = $arrayParams.rgSpoke21
     $spoke21location = $arrayParams.spoke21location
     $spoke21vnetName = $arrayParams.spoke21vnetName
     $spoke21AddressPrefix = $arrayParams.spoke21AddressPrefix
     $spoke21subnetFEName = $arrayParams.spoke21subnetFEName
     $spoke21subnetFEPrefix = $arrayParams.spoke21subnetFEPrefix
     $spoke21subnetBEName = $arrayParams.spoke21subnetBEName
     $spoke21subnetBEPrefix = $arrayParams.spoke21subnetBEPrefix
     $spoke21subnetWLName = $arrayParams.spoke21subnetWLName
     $spoke21subnetWLPrefix = $arrayParams.spoke21subnetWLPrefix
     $spoke21BAddressPrefix = $arrayParams.spoke21BAddressPrefix
     $spoke21lbFrontEndIP = $arrayParams.spoke21lbFrontEndIP
     $rgSpoke22 = $arrayParams.rgSpoke22
     $spoke22location = $arrayParams.spoke22location
     $spoke22vnetName = $arrayParams.spoke22vnetName
     $spoke22AddressPrefix = $arrayParams.spoke22AddressPrefix
     $spoke22subnetFEName = $arrayParams.spoke22subnetFEName
     $spoke22subnetFEPrefix = $arrayParams.spoke22subnetFEPrefix
     $spoke22subnetBEName = $arrayParams.spoke22subnetBEName
     $spoke22subnetBEPrefix = $arrayParams.spoke22subnetBEPrefix
     $spoke22subnetWLName = $arrayParams.spoke22subnetWLName
     $spoke22subnetWLPrefix = $arrayParams.spoke22subnetWLPrefix
     $spoke22BAddressPrefix = $arrayParams.spoke22BAddressPrefix
     $spoke22lbFrontEndIP = $arrayParams.spoke22lbFrontEndIP
}
catch {
     Write-Host 'error in reading the parameters file: '$inputParamsFile -ForegroundColor Yellow
     Exit
}

# checking the values of variables
Write-Host "$(Get-Date) - values from file: $inputParams" -ForegroundColor Yellow
if (!$subscriptionName) { Write-Host 'variable $subscriptionName is null' ; Exit }             else { Write-Host '   subscription name.......: '$subscriptionName -ForegroundColor Yellow }
if (!$rgWanName) { Write-Host 'variable $rgWanName is null' ; Exit }                           else { Write-Host '   resource group name.....: '$rgWanName -ForegroundColor Yellow }
if (!$vwanName) { Write-Host 'variable $vwanName is null' ; Exit }                             else { Write-Host '   vwan name...............: '$vwanName -ForegroundColor Yellow }
if (!$hub1Name) { Write-Host 'variable $hub1Name is null' ; Exit }                             else { Write-Host '   hub1 name...............: '$hub1Name -ForegroundColor Yellow }
if (!$hub1location) { Write-Host 'variable $hub1location is null' ; Exit }                     else { Write-Host '   hub1 location...........: '$hub1location -ForegroundColor Yellow }
if (!$hub1addressPrefix) { Write-Host 'variable $hub1addressPrefix is null' ; Exit }           else { Write-Host '   hub1 address prefix.....: '$hub1addressPrefix -ForegroundColor Yellow }
if (!$hub1vpnGwName) { Write-Host 'variable $hub1vpnGwName is null' ; Exit }                   else { Write-Host '   hub1 VPN gateway name...: '$hub1vpnGwName -ForegroundColor Yellow }
if (!$rgSpoke21) { Write-Host 'variable $rgSpoke21 is null' ; Exit }                           else { Write-Host '   spoke21 resource group..: '$rgSpoke21 -ForegroundColor Yellow }
if (!$spoke21location) { Write-Host 'variable $spoke21location is null' ; Exit }               else { Write-Host '   spoke21 location........: '$spoke21location -ForegroundColor Yellow }
if (!$spoke21vnetName) { Write-Host 'variable $spoke21vnetName is null' ; Exit }               else { Write-Host '   spoke21 VNet name.......: '$spoke21vnetName -ForegroundColor Yellow }
if (!$spoke21AddressPrefix) { Write-Host 'variable $spoke21AddressPrefix is null' ; Exit }     else { Write-Host '   spoke21 prefix..........: '$spoke21AddressPrefix -ForegroundColor Yellow }
if (!$spoke21subnetFEName) { Write-Host 'variable $spoke21subnetFEName is null' ; Exit }       else { Write-Host '   spoke21 subnetFE name...: '$spoke21subnetFEName -ForegroundColor Yellow }
if (!$spoke21subnetFEPrefix) { Write-Host 'variable $spoke21subnetFEPrefix is null' ; Exit }   else { Write-Host '   spoke21 subnetFE prefix.: '$spoke21subnetFEPrefix -ForegroundColor Yellow }
if (!$spoke21subnetBEName) { Write-Host 'variable $spoke21subnetBEName is null' ; Exit }       else { Write-Host '   spoke21 subnetBE name...: '$spoke21subnetBEName -ForegroundColor Yellow }
if (!$spoke21subnetBEPrefix) { Write-Host 'variable $spoke21subnetBEPrefix is null' ; Exit }   else { Write-Host '   spoke21 subnetBE prefix.: '$spoke21subnetBEPrefix -ForegroundColor Yellow }
if (!$spoke21subnetWLName) { Write-Host 'variable $spoke21subnetWLName is null' ; Exit }       else { Write-Host '   spoke21 subnetWL name...: '$spoke21subnetWLName -ForegroundColor Yellow }
if (!$spoke21subnetWLPrefix) { Write-Host 'variable $spoke21subnetWLPrefix is null' ; Exit }   else { Write-Host '   spoke21 subnetWL prefix.: '$spoke21subnetWLPrefix -ForegroundColor Yellow }
if (!$spoke21BAddressPrefix) { Write-Host 'variable $spoke21BAddressPrefix is null' ; Exit }   else { Write-Host '   spoke21B prefix.........: '$spoke21BAddressPrefix -ForegroundColor Yellow }
if (!$spoke21lbFrontEndIP) { Write-Host 'variable $spoke21lbFrontEndIP is null' ; Exit }       else { Write-Host '   spoke21 LB frontend IP..: '$spoke21lbFrontEndIP -ForegroundColor Yellow }
if (!$rgSpoke22) { Write-Host 'variable $rgSpoke22 is null' ; Exit }                           else { Write-Host '   spoke22 resource group..: '$rgSpoke22 -ForegroundColor Yellow }
if (!$spoke22location) { Write-Host 'variable $spoke22location is null' ; Exit }               else { Write-Host '   spoke22 location........: '$spoke22location -ForegroundColor Yellow }
if (!$spoke22vnetName) { Write-Host 'variable $spoke22vnetName is null' ; Exit }               else { Write-Host '   spoke22 VNet name.......: '$spoke22vnetName -ForegroundColor Yellow }
if (!$spoke22AddressPrefix) { Write-Host 'variable $spoke22AddressPrefix is null' ; Exit }     else { Write-Host '   spoke22 prefix..........: '$spoke22AddressPrefix -ForegroundColor Yellow }
if (!$spoke22subnetFEName) { Write-Host 'variable $spoke22subnetFEName is null' ; Exit }       else { Write-Host '   spoke22 subnetFE name...: '$spoke22subnetFEName -ForegroundColor Yellow }
if (!$spoke22subnetFEPrefix) { Write-Host 'variable $spoke22subnetFEPrefix is null' ; Exit }   else { Write-Host '   spoke22 subnetFE prefix.: '$spoke22subnetFEPrefix -ForegroundColor Yellow }
if (!$spoke22subnetBEName) { Write-Host 'variable $spoke22subnetBEName is null' ; Exit }       else { Write-Host '   spoke22 subnetBE name...: '$spoke22subnetBEName -ForegroundColor Yellow }
if (!$spoke22subnetBEPrefix) { Write-Host 'variable $spoke22subnetBEPrefix is null' ; Exit }   else { Write-Host '   spoke22 subnetBE prefix.: '$spoke22subnetBEPrefix -ForegroundColor Yellow }
if (!$spoke22subnetWLName) { Write-Host 'variable $spoke22subnetWLName is null' ; Exit }       else { Write-Host '   spoke22 subnetWL name...: '$spoke22subnetWLName -ForegroundColor Yellow }
if (!$spoke22subnetWLPrefix) { Write-Host 'variable $spoke22subnetWLPrefix is null' ; Exit }   else { Write-Host '   spoke22 subnetWL prefix.: '$spoke22subnetWLPrefix -ForegroundColor Yellow }
if (!$spoke22BAddressPrefix) { Write-Host 'variable $spoke22BAddressPrefix is null' ; Exit }   else { Write-Host '   spoke22B prefix.........: '$spoke22BAddressPrefix -ForegroundColor Yellow }
if (!$spoke22lbFrontEndIP) { Write-Host 'variable $spoke22lbFrontEndIP is null' ; Exit }       else { Write-Host '   spoke22 LB frontend IP..: '$spoke22lbFrontEndIP -ForegroundColor Yellow }

try {
     # check if exists the VPN GTW for site-to-site in vWAN
     # if it exists, the flag $deployVPNGtwS2S is set to false avoiding the reset of S2S VPN Gateway configuration
     write-host "$(Get-Date) - check if exists the S2S VPN GTW in vWAN: "$hub1vpnGwName -ForegroundColor Cyan
     Get-AzVpnGateway -ResourceGroupName $rgWanName -Name $hub1vpnGwName -ErrorAction Stop | Out-Null
     # variable to control the deployment of the S2S VPN Gateway in the hub1. 
     # if the VPN GTW already exists, the variable can be set to false to avoid the redeployment and the reset of the configuration of the S2S VPN GTW in the hub1
     $deployVPNGtw = $false
     write-host "$(Get-Date) - skipping the creation of S2S VPN GTW in vWAN: $hub1vpnGwName" -ForegroundColor Cyan
}
catch {
     write-host "$(Get-Date) - S2S VPN GTW in vWAN: $hub1vpnGwName does not exist" -ForegroundColor Cyan
     $deployVPNGtw = $true
}

# to force the creation/reployment of the VPN Gatway in the hub uncomment the following line:
# $deployVPNGtw = $true

$subscr = Get-AzSubscription -SubscriptionName $subscriptionName
Select-AzSubscription -SubscriptionId $subscr.Id

# Login Check
Try {
     Write-Host 'Using Subscription: ' -NoNewline
     Write-Host $((Get-AzContext).Name) -ForegroundColor Green
}
Catch {
     Write-Warning 'You are not logged in dummy. Login and try again!'
     Return
}


$parameters = @{
     "vwanName"              = $vwanName;
     "hub1Name"              = $hub1Name;
     "hub1location"          = $hub1location;
     "hub1addressPrefix"     = $hub1addressPrefix;
     "rgSpoke21"             = $rgSpoke21;
     "spoke21vnetName"       = $spoke21vnetName;
     "spoke21AddressPrefix"  = $spoke21AddressPrefix;
     "spoke21subnetFEName"   = $spoke21subnetFEName;
     "spoke21subnetFEPrefix" = $spoke21subnetFEPrefix;
     "spoke21subnetBEName"   = $spoke21subnetBEName;
     "spoke21subnetBEPrefix" = $spoke21subnetBEPrefix;
     "spoke21subnetWLName"   = $spoke21subnetWLName;
     "spoke21subnetWLPrefix" = $spoke21subnetWLPrefix;
     "spoke21BAddressPrefix" = $spoke21BAddressPrefix;
     "spoke21lbFrontEndIP"   = $spoke21lbFrontEndIP;
     "rgSpoke22"             = $rgSpoke22;
     "spoke22vnetName"       = $spoke22vnetName;
     "spoke22AddressPrefix"  = $spoke22AddressPrefix;
     "spoke22subnetFEName"   = $spoke22subnetFEName;
     "spoke22subnetFEPrefix" = $spoke22subnetFEPrefix;
     "spoke22subnetBEName"   = $spoke22subnetBEName;
     "spoke22subnetBEPrefix" = $spoke22subnetBEPrefix;
     "spoke22subnetWLName"   = $spoke22subnetWLName;
     "spoke22subnetWLPrefix" = $spoke22subnetWLPrefix;
     "spoke22BAddressPrefix" = $spoke22BAddressPrefix;
     "spoke22lbFrontEndIP"   = $spoke22lbFrontEndIP;
     "hub1vpnGwName"         = $hub1vpnGwName;
     "deployVPNGtwS2S"       = $deployVPNGtw
}

$location = $hub1location
# Create Resource Group
Write-Host "$(Get-Date) - creating Resource Group: "$rgWanName -ForegroundColor Cyan
Try {
     Get-AzResourceGroup -Name $rgWanName -ErrorAction Stop
     Write-Host 'Resource exists, skipping'
}
Catch { 
     New-AzResourceGroup -Name $rgWanName -Location $location | Out-Null
     Write-Host 'Resource group created' -ForegroundColor Green
     # Set tag on the resource group
     Set-AzResourceGroup -Name $rgWanName -Tag @{"PM owner" = "fabferri"; "Project" = "vWAN validation" }
}

$startTime = Get-Date
write-host "$(Get-Date) - running ARM template:"$templateFile
New-AzResourceGroupDeployment  -Name $deploymentName -ResourceGroupName $rgWanName -TemplateFile $templateFile -TemplateParameterObject $parameters -Verbose 

Write-Host "$(Get-Date) - setup completed" -ForegroundColor Green
$endTime = Get-Date
$timeDiff = New-TimeSpan $startTime $endTime
$mins = $timeDiff.Minutes
$secs = $timeDiff.Seconds
$runTime = '{0:00}:{1:00} (M:S)' -f $mins, $secs
Write-Host "$(Get-Date) - Script completed" -ForegroundColor Green
Write-Host "Time to complete: "$runTime







