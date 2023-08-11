#
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
#   $mngIP: management public IP to connect in SSH to the Azure VMs
#   $RGTagExpireDate: tag assigned to the resource group. It is used to track the expiration date of the deployment in testing.
#   $RGTagContact: tag assigned to the resource group. It is used to email to the owner of th deployment
#   $RGTagNinja: tag assigned to the resource group. Alias of the user
#   $RGTagUsage: tag assigned to the resource group. Short description of the deployment purpose
#
################# Input parameters #################
$deploymentName = 'vwan-site'
$armTemplateFile = '03-vwan-site.json'
$inputParams = 'init.json'
####################################################

$pathFiles  = Split-Path -Parent $PSCommandPath
$templateFile = "$pathFiles\$armTemplateFile"

$pathFiles = Split-Path -Parent $PSCommandPath
$templateFile = "$pathFiles\$armTemplateFile"

# reading the input parameter file $inputParams and convert the values in hashtable 
If (Test-Path -Path $pathFiles\$inputParams) 
{
     # convert the json into PSCustomObject
     $jsonObj = Get-Content -Raw $pathFiles\$inputParams | ConvertFrom-Json
     if ($null -eq $jsonObj) {
          Write-Host "file $inputParams is empty"
          Exit
     }
     # convert the PSCustomObject in hashtable
     if ($jsonObj -is [psobject]) {
          $hash = @{}
          foreach ($property in $jsonObj.PSObject.Properties) {
               $hash[$property.Name] = $property.Value
          }
     }
     foreach ($key in $hash.keys) {
          $message = '{0} = {1} ' -f $key, $hash[$key]
          Write-Output $message
          Try { New-Variable -Name $key -Value $hash[$key] -ErrorAction Stop }
          Catch { Set-Variable -Name $key -Value $hash[$key] }
     }
} 
else { Write-Warning "$inputParams file not found, please change to the directory where these scripts reside ($pathFiles) and ensure this file is present."; Return }

# checking the values of variables
Write-Host "$(Get-Date) - values from file: $inputParams" -ForegroundColor Yellow
if (!$adminUsername) { Write-Host 'variable $adminUsername is null' ; Exit } else { Write-Host '   administrator username: '$adminUsername -ForegroundColor Green}
if (!$adminPassword) { Write-Host 'variable $adminPassword is null' ; Exit } else { Write-Host '   administrator password: '$adminPassword -ForegroundColor Green}
if (!$subscriptionName) { Write-Host 'variable $subscriptionName is null' ; Exit } else { Write-Host '   subscription name..: '$subscriptionName -ForegroundColor Yellow}
if (!$ResourceGroupName) { Write-Host 'variable $ResourceGroupName is null' ; Exit } else { Write-Host '   resource group name: '$ResourceGroupName -ForegroundColor Yellow}
if (!$hub1location) { Write-Host 'variable $hub1location is null' ; Exit } else { Write-Host '   hub1 location......: '$hub1location -ForegroundColor Yellow}
if (!$hub2location) { Write-Host 'variable $hub2location is null' ; Exit } else { Write-Host '   hub2 location......: '$hub2location -ForegroundColor Yellow}
if (!$branch1location) { Write-Host 'variable $branch1location is null' ; Exit } else { Write-Host '   branch1 location...: '$branch1location -ForegroundColor Yellow}
if (!$branch2location) { Write-Host 'variable$branch2location is null' ; Exit } else { Write-Host '   branch2 location...: '$branch2location -ForegroundColor Yellow}
if (!$hub1Name) { Write-Host 'variable $hub1Name is null' ; Exit } else {   Write-Host '   hub1 name..........: '$hub1Name -ForegroundColor Yellow}
if (!$hub2Name) { Write-Host 'variable $hub2Name is null' ; Exit } else {   Write-Host '   hub2 name..........: '$hub2Name -ForegroundColor Yellow}
$rgName=$ResourceGroupName

Write-Host 'getting the branch1 VPN GTW:'
$branch1vpnGtwName ='vpnGw1'
try {($branch1vpnGtw = Get-AzVirtualNetworkGateway -ResourceGroupName $rgName -Name $branch1vpnGtwName -ErrorAction Stop) | Out-Null}
catch { Write-Host 'VPN GTW $vpnGtwBranchName not found' ; Exit } 

# Out-String converts the system.object in string
$branch1vpnPublicIP1 = Out-String -InputObject ($branch1vpnGtw.BgpSettings.BgpPeeringAddresses[0].TunnelIpAddresses) -NoNewline
$branch1vpnPublicIP2 = Out-String -InputObject ($branch1vpnGtw.BgpSettings.BgpPeeringAddresses[1].TunnelIpAddresses) -NoNewline
$branch1vpnBGPpeer1 = Out-String -InputObject ($branch1vpnGtw.BgpSettings.BgpPeeringAddresses[0].DefaultBgpIpAddresses) -NoNewline
$branch1vpnBGPpeer2 = Out-String -InputObject ($branch1vpnGtw.BgpSettings.BgpPeeringAddresses[1].DefaultBgpIpAddresses) -NoNewline

if (!$branch1vpnPublicIP1) { Write-Host 'variable $branch1vpnPublicIP1 is null' ; Exit } else { Write-Host '   branch1-VPN public IP1..: '$branch1vpnPublicIP1 -ForegroundColor Yellow}
if (!$branch1vpnPublicIP2) { Write-Host 'variable $branch1vpnPublicIP2 is null' ; Exit } else { Write-Host '   branch1-VPN public IP1..: '$branch1vpnPublicIP2 -ForegroundColor Yellow}
if (!$branch1vpnBGPpeer1) { Write-Host 'variable $branch1vpnBGPpeer1 is null' ; Exit } else { Write-Host '   branch1-VPN-BGP peer IP1..: '$branch1vpnBGPpeer1 -ForegroundColor Yellow}
if (!$branch1vpnBGPpeer2) { Write-Host 'variable $branch1vpnBGPpeer2 is null' ; Exit } else { Write-Host '   branch1-VPN-BGP peer IP2..: '$branch1vpnBGPpeer2 -ForegroundColor Yellow}
####

Write-Host 'getting the branch1 VPN GTW:'
$branch2vpnGtwName ='vpnGw2'
try {($branch2vpnGtw = Get-AzVirtualNetworkGateway -ResourceGroupName $rgName -Name $branch2vpnGtwName -ErrorAction Stop) | Out-Null}
catch { Write-Host 'VPN GTW $vpnGtwBranchName not found' ; Exit } 

# Out-String converts the system.object in string
$branch2vpnPublicIP1 = Out-String -InputObject ($branch2vpnGtw.BgpSettings.BgpPeeringAddresses[0].TunnelIpAddresses) -NoNewline
$branch2vpnPublicIP2 = Out-String -InputObject ($branch2vpnGtw.BgpSettings.BgpPeeringAddresses[1].TunnelIpAddresses) -NoNewline
$branch2vpnBGPpeer1 = Out-String -InputObject ($branch2vpnGtw.BgpSettings.BgpPeeringAddresses[0].DefaultBgpIpAddresses) -NoNewline
$branch2vpnBGPpeer2 = Out-String -InputObject ($branch2vpnGtw.BgpSettings.BgpPeeringAddresses[1].DefaultBgpIpAddresses) -NoNewline

if (!$branch2vpnPublicIP1) { Write-Host 'variable $branch2vpnPublicIP1 is null' ; Exit } else { Write-Host '   branch2-VPN public IP1..: '$branch2vpnPublicIP1 -ForegroundColor Yellow}
if (!$branch2vpnPublicIP2) { Write-Host 'variable $branch2vpnPublicIP2 is null' ; Exit } else { Write-Host '   branch2-VPN public IP1..: '$branch2vpnPublicIP2 -ForegroundColor Yellow}
if (!$branch2vpnBGPpeer1) { Write-Host 'variable $branch2vpnBGPpeer1 is null' ; Exit } else { Write-Host '   branch2-VPN-BGP peer IP1..: '$branch2vpnBGPpeer1 -ForegroundColor Yellow}
if (!$branch2vpnBGPpeer2) { Write-Host 'variable $branch2vpnBGPpeer2 is null' ; Exit } else { Write-Host '   branch2-VPN-BGP peer IP2..: '$branch2vpnBGPpeer2 -ForegroundColor Yellow}


$subscr=Get-AzSubscription -SubscriptionName $subscriptionName
Select-AzSubscription -SubscriptionId $subscr.Id

# Login Check
Try {Write-Host 'Using Subscription: ' -NoNewline
     Write-Host $((Get-AzContext).Name) -ForegroundColor Green}
Catch {
    Write-Warning 'You are not logged in dummy. Login and try again!'
    Return}


$parameters=@{
              "hub1location" = $hub1location;
              "hub2location" = $hub2location;
              "hub1Name" = $hub1Name;
              "hub2Name" = $hub2Name;
              "branch1vpnPublicIP1" = $branch1vpnPublicIP1;
              "branch1vpnPublicIP2" = $branch1vpnPublicIP2;
              "branch1vpnBGPpeer1" = $branch1vpnBGPpeer1;
              "branch1vpnBGPpeer2" = $branch1vpnBGPpeer2;
              "branch2vpnPublicIP1" = $branch2vpnPublicIP1;
              "branch2vpnPublicIP2" = $branch2vpnPublicIP2;
              "branch2vpnBGPpeer1" = $branch2vpnBGPpeer1;
              "branch2vpnBGPpeer2" = $branch2vpnBGPpeer2;
              "sharedKey" = $sharedKey
              }

$location=$hub1location      
# Create Resource Group
Write-Host (Get-Date)' - ' -NoNewline
Write-Host 'Creating Resource Group' -ForegroundColor Cyan
Try { Get-AzResourceGroup -Name $rgName -ErrorAction Stop
     Write-Host 'Resource exists, skipping'}
Catch { New-AzResourceGroup -Name $rgName -Location $location}


$startTime = "$(Get-Date)"
$runTime=Measure-Command {
   write-host "running ARM template:"$templateFile
   New-AzResourceGroupDeployment  -Name $deploymentName -ResourceGroupName $rgName -TemplateFile $templateFile -TemplateParameterObject $parameters -Verbose 
}
 
write-host "runtime...: "$runTime.ToString() -ForegroundColor Yellow
write-host "start time: "$startTime -ForegroundColor Yellow
write-host "endt time.: "$(Get-Date) -ForegroundColor Yellow






