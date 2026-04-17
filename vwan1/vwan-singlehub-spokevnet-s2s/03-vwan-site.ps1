#
#  variables in init.json file:
#   $subscriptionName: Azure subscription name
#   $ResourceGroupName: resource group name
#   $hub1location: Azure region to deploy the virtual hub1
#   $branch1location: Azure region to deploy the branch1
#   $hub1Name: name of the virtual hub1
#   $sharedKey: share secret of the site-to-site VPN between the branch and the hub1
#   $mngIP: public IP to filter inbound SSH connection to the VMs. it can be empty if you do not want to set a restriction.
#   $adminUsername: administrator username
#   $adminPassword: administrator password
#
################# Input parameters #################
$deploymentName = 'vwan-site'
$armTemplateFile = '03-vwan-site.json'
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
     $hub1vpnGwName = $arrayParams.hub1vpnGwName
     $sharedKey = $arrayParams.sharedKey
     $rgBranch1 = $arrayParams.rgBranch1
     $branch1vpnGtwName = $arrayParams.branch1vpnGtwName
}
catch {
     Write-Host 'error in reading the parameters file: '$inputParamsFile -ForegroundColor Yellow
     Exit
}

# checking the values of variables
Write-Host "$(Get-Date) - values from file: $inputParams" -ForegroundColor Yellow
if (!$subscriptionName) { Write-Host 'variable $subscriptionName is null' ; Exit }   else { Write-Host '   subscription name.....: '$subscriptionName -ForegroundColor Yellow }
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
if (!$sharedKey) { Write-Host 'variable $sharedKey is null' ; Exit }                 else { Write-Host '   shared key..............: '$sharedKey -ForegroundColor Yellow }
if (!$hub1vpnGwName) { Write-Host 'variable $hub1vpnGwName is null' ; Exit }         else { Write-Host '   hub1 VPN gateway name...: '$hub1vpnGwName -ForegroundColor Yellow }
if (!$branch1vpnGtwName) { Write-Host 'variable $branch1vpnGtwName is null' ; Exit } else { Write-Host '   branch1 VPN gateway name: '$branch1vpnGtwName -ForegroundColor Yellow }
if (!$rgBranch1) { Write-Host 'variable $rgBranch1 is null' ; Exit }                 else { Write-Host '   branch1 resource group..: '$rgBranch1 -ForegroundColor Yellow }

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
catch { Write-Host 'VPN GTW $vpnGtwBranchName not found' ; Exit } 

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
     "hub1location"        = $hub1location;
     "hub1Name"            = $hub1Name;
     "hub1vpnGwName"       = $hub1vpnGwName;
     "branch1vpnPublicIP1" = $branch1vpnPublicIP1;
     "branch1vpnPublicIP2" = $branch1vpnPublicIP2;
     "branch1vpnBGPpeer1"  = $branch1vpnBGPpeer1;
     "branch1vpnBGPpeer2"  = $branch1vpnBGPpeer2;
     "sharedKey"           = $sharedKey
}

$location = $hub1location      
# Create Resource Group
Write-Host "$(Get-Date) - Creating Resource Group: $rgName" -ForegroundColor Cyan
Try {
     Get-AzResourceGroup -Name $rgName -ErrorAction Stop
     Write-Host 'Resource exists, skipping'
}
Catch { New-AzResourceGroup -Name $rgName -Location $location }


$startTime = Get-Date
write-host "$(Get-Date) - running ARM template:"$templateFile
New-AzResourceGroupDeployment  -Name $deploymentName -ResourceGroupName $rgName -TemplateFile $templateFile -TemplateParameterObject $parameters -Verbose 

Write-Host "$(Get-Date) - setup completed" -ForegroundColor Green
$endTime = Get-Date
$timeDiff = New-TimeSpan $startTime $endTime
$mins = $timeDiff.Minutes
$secs = $timeDiff.Seconds
$runTime = '{0:00}:{1:00} (M:S)' -f $mins, $secs
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Script completed" -ForegroundColor Green
Write-Host "Time to complete: "$runTime






