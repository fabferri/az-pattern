#
#  variables in init.json file:
#   $subscriptionName: Azure subscription name
#   $rgWanName: resource group name for the virtual WAN resources
#   $rgBranch: resource group name for branch1 resources
#   $vwanName: name of the virtual WAN
#   $hub1location: Azure region to deploy the virtual hub1
#   $hub1Name: name of the virtual hub1
#   $hub1vpnGwName: name of the VPN gateway in the virtual hub
#   $branch1Name: name of the branch1 VNet/VPN site
#   $branch1AddressPrefix: branch1 VNet address prefix
#   $branch1gtwASN: branch1 VPN gateway ASN
#   $branch1vpnGtwName: branch1 VPN gateway name
#   $hub1ToBranchConnectionName: hub-to-branch VPN connection name
#   $vpnSiteLink1Name: name of the first VPN site link
#   $vpnSiteLink2Name: name of the second VPN site link
#   $sharedKey: share secret of the site-to-site VPN between the branch and the hub1
#
################# Input parameters #################
param(
     [string]$initFile = 'init.json'
)
$deploymentName = (Get-Item $PSCommandPath).BaseName
$armTemplateFile = '03-vwan-site.json'
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
     $hub1vpnGwName = $arrayParams.hub1vpnGwName
     $rgBranch1 = $arrayParams.rgBranch
     $branch1Name = $arrayParams.branch1Name
     $branch1AddressPrefix = $arrayParams.branch1AddressPrefix
     $branch1vpnGtwName = $arrayParams.branch1vpnGtwName
     $branch1gtwASN = $arrayParams.branch1gtwASN
     $hub1ToBranchConnectionName = $arrayParams.hub1ToBranchConnectionName
     $vpnSiteLink1Name = $arrayParams.vpnSiteLink1Name
     $vpnSiteLink2Name = $arrayParams.vpnSiteLink2Name
     $sharedKey = $arrayParams.sharedKey
}
catch {
     Write-Host 'error in reading the parameters file: '$inputParamsFile -ForegroundColor Yellow
     Exit
}

# checking the values of variables
Write-Host "$(Get-Date) - values from file: $inputParams" -ForegroundColor Yellow
if (!$subscriptionName) { Write-Host 'variable $subscriptionName is null' ; Exit }                     else { Write-Host '   subscription name.......: '$subscriptionName -ForegroundColor Yellow }
if (!$rgWanName) { Write-Host 'variable $rgWanName is null' ; Exit }                                   else { Write-Host '   resource group name.....: '$rgWanName -ForegroundColor Yellow }
if (!$vwanName) { Write-Host 'variable $vwanName is null' ; Exit }                                     else { Write-Host '   vwan name...............: '$vwanName -ForegroundColor Yellow }
if (!$hub1Name) { Write-Host 'variable $hub1Name is null' ; Exit }                                     else { Write-Host '   hub1 name...............: '$hub1Name -ForegroundColor Yellow }
if (!$hub1location) { Write-Host 'variable $hub1location is null' ; Exit }                             else { Write-Host '   hub1 location...........: '$hub1location -ForegroundColor Yellow }
if (!$hub1vpnGwName) { Write-Host 'variable $hub1vpnGwName is null' ; Exit }                           else { Write-Host '   hub1 VPN gateway name...: '$hub1vpnGwName -ForegroundColor Yellow }
if (!$rgBranch1) { Write-Host 'variable $rgBranch1 is null' ; Exit }                                   else { Write-Host '   branch1 resource group..: '$rgBranch1 -ForegroundColor Yellow }
if (!$branch1Name) { Write-Host 'variable $branch1Name is null' ; Exit }                               else { Write-Host '   branch1 name............: '$branch1Name -ForegroundColor Yellow }
if (!$branch1AddressPrefix) { Write-Host 'variable $branch1AddressPrefix is null' ; Exit }             else { Write-Host '   branch1 address prefix..: '$branch1AddressPrefix -ForegroundColor Yellow }
if (!$branch1vpnGtwName) { Write-Host 'variable $branch1vpnGtwName is null' ; Exit }                   else { Write-Host '   branch1 VPN gateway name: '$branch1vpnGtwName -ForegroundColor Yellow }
if (!$branch1gtwASN) { Write-Host 'variable $branch1gtwASN is null' ; Exit }                           else { Write-Host '   branch1 gateway ASN.....: '$branch1gtwASN -ForegroundColor Yellow }
if (!$hub1ToBranchConnectionName) { Write-Host 'variable $hub1ToBranchConnectionName is null' ; Exit } else { Write-Host '   hub-to-branch conn name.: '$hub1ToBranchConnectionName -ForegroundColor Yellow }
if (!$vpnSiteLink1Name) { Write-Host 'variable $vpnSiteLink1Name is null' ; Exit }                     else { Write-Host '   VPN site link 1 name....: '$vpnSiteLink1Name -ForegroundColor Yellow }
if (!$vpnSiteLink2Name) { Write-Host 'variable $vpnSiteLink2Name is null' ; Exit }                     else { Write-Host '   VPN site link 2 name....: '$vpnSiteLink2Name -ForegroundColor Yellow }
if (!$sharedKey) { Write-Host 'variable $sharedKey is null' ; Exit }                                   else { Write-Host '   shared key..............: '$sharedKey -ForegroundColor Yellow }

# Login Check
Try {
     Write-Host 'Using Subscription: ' -NoNewline
     Write-Host $((Get-AzContext).Name) -ForegroundColor Green
}
Catch {
     Write-Warning 'You are not logged in dummy. Login and try again!'
     Return
}

$subscr = Get-AzSubscription -SubscriptionName $subscriptionName
Select-AzSubscription -SubscriptionId $subscr.Id


Write-Host 'getting the branch1 VPN GTW:'
try { ($branch1vpnGtw = Get-AzVirtualNetworkGateway -ResourceGroupName $rgBranch1 -Name $branch1vpnGtwName -ErrorAction Stop) | Out-Null }
catch { Write-Host "VPN GTW $branch1vpnGtwName not found" ; Exit } 

# Out-String converts the system.object in string
$branch1vpnPublicIP1 = Out-String -InputObject ($branch1vpnGtw.BgpSettings.BgpPeeringAddresses[0].TunnelIpAddresses) -NoNewline
$branch1vpnPublicIP2 = Out-String -InputObject ($branch1vpnGtw.BgpSettings.BgpPeeringAddresses[1].TunnelIpAddresses) -NoNewline
$branch1vpnBGPpeer1 = Out-String -InputObject ($branch1vpnGtw.BgpSettings.BgpPeeringAddresses[0].DefaultBgpIpAddresses) -NoNewline
$branch1vpnBGPpeer2 = Out-String -InputObject ($branch1vpnGtw.BgpSettings.BgpPeeringAddresses[1].DefaultBgpIpAddresses) -NoNewline

if (!$branch1vpnPublicIP1) { Write-Host 'variable $branch1vpnPublicIP1 is null' ; Exit } else { Write-Host '   branch1-VPN public IP1....: '$branch1vpnPublicIP1 -ForegroundColor Yellow }
if (!$branch1vpnPublicIP2) { Write-Host 'variable $branch1vpnPublicIP2 is null' ; Exit } else { Write-Host '   branch1-VPN public IP2....: '$branch1vpnPublicIP2 -ForegroundColor Yellow }
if (!$branch1vpnBGPpeer1) { Write-Host 'variable $branch1vpnBGPpeer1 is null' ; Exit }   else { Write-Host '   branch1-VPN-BGP peer IP1..: '$branch1vpnBGPpeer1 -ForegroundColor Yellow }
if (!$branch1vpnBGPpeer2) { Write-Host 'variable $branch1vpnBGPpeer2 is null' ; Exit }   else { Write-Host '   branch1-VPN-BGP peer IP2..: '$branch1vpnBGPpeer2 -ForegroundColor Yellow }
####



$parameters = @{
     "vwanName"            = $vwanName;
     "hub1location"        = $hub1location;
     "hub1Name"            = $hub1Name;
     "hub1vpnGwName"       = $hub1vpnGwName;
     "branch1vpnASN"       = $branch1gtwASN;
     "h1vpnsiteAddressspaceList" = @($branch1AddressPrefix);
     "vpnsite1Name"        = $branch1Name;
     "hub1ToBranchConnectionName" = $hub1ToBranchConnectionName;
     "vpnSiteLink1Name"    = $vpnSiteLink1Name;
     "vpnSiteLink2Name"    = $vpnSiteLink2Name;
     "branch1vpnPublicIP1" = $branch1vpnPublicIP1;
     "branch1vpnPublicIP2" = $branch1vpnPublicIP2;
     "branch1vpnBGPpeer1"  = $branch1vpnBGPpeer1;
     "branch1vpnBGPpeer2"  = $branch1vpnBGPpeer2;
     "sharedKey"           = $sharedKey
}

# Create Resource Group
Write-Host "$(Get-Date) - Creating Resource Group: $rgWanName" -ForegroundColor Cyan
Try {
     Get-AzResourceGroup -Name $rgWanName -ErrorAction Stop
     Write-Host 'Resource exists, skipping'
}
Catch { 
     New-AzResourceGroup -Name $rgWanName -Location $hub1location 
     Write-Host "$(Get-Date) - Resource group created: "$rgWanName -ForegroundColor Green
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
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Script completed" -ForegroundColor Green
Write-Host "Time to complete: "$runTime






