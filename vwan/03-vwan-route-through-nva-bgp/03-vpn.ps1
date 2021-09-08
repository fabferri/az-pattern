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
#   $mngIP:management public IP to connect in SSH to the Azure VMs
#   $RGTagExpireDate: tag assigned to the resource group. It is used to track the expiration date of the deployment in testing.
#   $RGTagContact: tag assigned to the resource group. It is used to email to the owner of th deployment
#   $RGTagNinja: tag assigned to the resource group. Alias of the user
#   $RGTagUsage: tag assigned to the resource group. Short description of the deployment purpose
#
################# Input parameters #################
$deploymentName = 'vpn-branches'
$armTemplateFile = '03-vpn.json'
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
if (!$sharedKey) { Write-Host 'variable $sharedKey is null' ; Exit } else { Write-Host '   shared key VPN GTW.: '$sharedKey -ForegroundColor Yellow}
if (!$mngIP) { Write-Host 'variable $mngIP is null' ; Exit } else { Write-Host '   mngIP..............: '$mngIP -ForegroundColor Yellow}
if (!$RGTagExpireDate) { Write-Host 'variable $RGTagExpireDate is null' ; Exit } else { Write-Host '   RGTagExpireDate....: '$RGTagExpireDate -ForegroundColor Yellow}
if (!$RGTagContact) { Write-Host 'variable $RGTagContact is null' ; Exit } else { Write-Host '   RGTagContact.......: '$RGTagContact -ForegroundColor Yellow}
if (!$RGTagNinja) { Write-Host 'variable $RGTagNinja is null' ; Exit } else { Write-Host '   RGTagNinja.........: '$RGTagNinja -ForegroundColor Yellow}
if (!$RGTagUsage) { Write-Host 'variable $RGTagUsage is null' ; Exit } else { Write-Host '   RGTagUsage.........: '$RGTagUsage -ForegroundColor Yellow}
$rgName=$ResourceGroupName


# VPN GTW for site-to-site in vWAN
$hub1vpnGtwName=$hub1Name+'_S2SvpnGW'
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
$hub2vpnGtwName=$hub2Name+'_S2SvpnGW'
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


$subscr=Get-AzSubscription -SubscriptionName $subscriptionName
Select-AzSubscription -SubscriptionId $subscr.Id

# Login Check
Try {Write-Host 'Using Subscription: ' -NoNewline
     Write-Host $((Get-AzContext).Name) -ForegroundColor Green}
Catch {
    Write-Warning 'You are not logged in dummy. Login and try again!'
    Return}

$parameters=@{
              "adminUsername" = $adminUsername;
              "adminPassword" = $adminPassword;
              "mngIP" = $mngIP;
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
              "sharedKey" = $sharedKey
              }


$location=$hub1location             
# Create Resource Group
Write-Host (Get-Date)' - ' -NoNewline
Write-Host 'Creating Resource Group' -ForegroundColor Cyan
Try { Get-AzResourceGroup -Name $rgName -ErrorAction Stop
     Write-Host 'Resource exists, skipping'}
Catch { New-AzResourceGroup -Name $rgName -Location $location}

# set a tag on the resource group if it doesn't exist.
if ((Get-AzResourceGroup -Name $rgName).Tags -eq $null)
{
  # Add Tag Values to the Resource Group
  Set-AzResourceGroup -Name $rgName -Tag @{Expires=$RGTagExpireDate; Contacts=$RGTagContact; Pathfinder=$RGTagNinja; Usage=$RGTagUsage} | Out-Null
}

$startTime = "$(Get-Date)"
$runTime=Measure-Command {
   write-host "running ARM template:"$templateFile
   New-AzResourceGroupDeployment  -Name $deploymentName -ResourceGroupName $rgName -TemplateFile $templateFile -TemplateParameterObject $parameters -Verbose 
}
 
write-host "runtime...: "$runTime.ToString() -ForegroundColor Yellow
write-host "start time: "$startTime -ForegroundColor Yellow
write-host "endt time.: "$(Get-Date) -ForegroundColor Yellow
