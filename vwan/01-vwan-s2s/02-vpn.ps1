#
#  variables in init.json file:
#    $dminUsername     : administrator username of the Azure VMs
#    $adminPassword    : administrator password of the Azure VMs
#    $subscriptionName : Azure subscription name
#    $ResourceGroupName: name of the resource group
#    $hub1location     : Azure region of the virtual hub1
#    $branch1location  : Azure region to deploy the branch1
#    $hub1Name         : name of the virtual hub1
#    $sharedKey        : VPN shared secret
#    $mngIP            : public IP used to connect in SSH to the Azure VMs 
#    $RGTagExpireDate  : tag assigned to the resource group. It is used to track the expiration date of the deployment in testing.
#    $RGTagContact     : tag assigned to the resource group. It is used to email to the owner of the deployment
#    $RGTagNinja       : alias of the user
#    $RGTagUsage       : short description of the deployment purpose
#
[CmdletBinding()]
param (
    [Parameter( Mandatory = $false, ValueFromPipeline=$false, HelpMessage='VMs administrator username')]
    [string]$adminUsername = "edge",
 
    [Parameter(Mandatory = $false, HelpMessage='VMs administrator password')]
    [string]$adminPassword = "IJudpobU,y6("
    )

################# Input parameters #################
$deploymentName = 'vpn'
$armTemplateFile = '02-vpn.json'
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
if (!$branch1location) { Write-Host 'variable $hub1_location is null' ; Exit } else { Write-Host '   branch1 location...: '$branch1location -ForegroundColor Yellow}
if (!$hub1Name) { Write-Host 'variable $hub1Name is null' ; Exit } else {   Write-Host '   hub1 name..........: '$hub1Name -ForegroundColor Yellow}
if (!$sharedKey) { Write-Host 'variable $sharedKey is null' ; Exit } else { Write-Host '   shared key VPN GTW.: '$sharedKey -ForegroundColor Yellow}
if (!$mngIP) { Write-Host 'variable $mngIP is null' ; Exit } else { Write-Host '   mngIP..............: '$mngIP -ForegroundColor Yellow}
if (!$RGTagExpireDate) { Write-Host 'variable $RGTagExpireDate is null' ; Exit } else { Write-Host '   RGTagExpireDate....: '$RGTagExpireDate -ForegroundColor Yellow}
if (!$RGTagContact) { Write-Host 'variable $RGTagContact is null' ; Exit } else { Write-Host '   RGTagContact.......: '$RGTagContact -ForegroundColor Yellow}
if (!$RGTagNinja) { Write-Host 'variable $RGTagNinja is null' ; Exit } else { Write-Host '   RGTagNinja.........: '$RGTagNinja -ForegroundColor Yellow}
if (!$RGTagUsage) { Write-Host 'variable $RGTagUsage is null' ; Exit } else { Write-Host '   RGTagUsage.........: '$RGTagUsage -ForegroundColor Yellow}
$rgName=$ResourceGroupName

# VPN GTW for site-to-site in vWAN
$hub1=$hub1Name+'_S2SvpnGW'
$vpnGateway = Get-AzVpnGateway -ResourceGroupName $rgName -Name $hub1
#getting public IPs VPN GTW
#$vWAN_PublicIP1=$vpnGateway.IpConfigurations.PublicIpAddress[0]
#$vWAN_PublicIP2=$vpnGateway.IpConfigurations.PublicIpAddress[1]
#$remotevWAN_BGPIP1=($vpnGateway.BgpSettings.BgpPeeringAddresses[0].DefaultBgpIpAddresses) | Out-String
#$remotevWAN_BGPIP2=($vpnGateway.BgpSettings.BgpPeeringAddresses[1].DefaultBgpIpAddresses) | Out-String


$hub1_vpnPublicIP1=Out-String -InputObject ($vpnGateway.IpConfigurations.PublicIpAddress[0]) -NoNewline
$hub1_vpnPublicIP2=Out-String -InputObject ($vpnGateway.IpConfigurations.PublicIpAddress[1]) -NoNewline
$hub1_vpnBGPIP1=Out-String -InputObject ($vpnGateway.BgpSettings.BgpPeeringAddresses[0].DefaultBgpIpAddresses) -NoNewline
$hub1_vpnBGPIP2=Out-String -InputObject ($vpnGateway.BgpSettings.BgpPeeringAddresses[1].DefaultBgpIpAddresses) -NoNewline



if (!$hub1_vpnPublicIP1) { Write-Host 'variable $hub1_vpnPublicIP1 is null' ; Exit } else { Write-Host '   vWAN-vpn public IP1....: '$hub1_vpnPublicIP1 -ForegroundColor Cyan}
if (!$hub1_vpnPublicIP2) { Write-Host 'variable $hub1_vpnPublicIP2 is null' ; Exit } else { Write-Host '   vWAN-vpn public IP2....: '$hub1_vpnPublicIP2 -ForegroundColor Cyan}
if (!$hub1_vpnBGPIP1) { Write-Host 'variable $hub1_vpnBGPIP1 is null' ; Exit } else { Write-Host '   vWAN-vpn remote BGP IP1: '$hub1_vpnBGPIP1 -ForegroundColor Cyan}
if (!$hub1_vpnBGPIP2) { Write-Host 'variable $hub1_vpnBGPIP2 is null' ; Exit } else { Write-Host '   vWAN-vpn remote BGP IP2: '$hub1_vpnBGPIP2 -ForegroundColor Cyan}


$subscr=Get-AzSubscription -SubscriptionName $subscriptionName
Select-AzSubscription -SubscriptionId $subscr.Id

# Login Check
Try {Write-Host 'Using Subscription: ' -NoNewline
     Write-Host $((Get-AzContext).Name) -ForegroundColor Green}
Catch {
    Write-Warning 'You are not logged in dummy. Login and try again!'
    Return}


$parameters=@{
              "branch1location" = $branch1location;
              "adminUsername" = $adminUsername;
              "adminPassword" = $adminPassword;
              "mngIP" = $mngIP;
              "hub1_vpnPublicIP1" = $hub1_vpnPublicIP1;
              "hub1_vpnPublicIP2" = $hub1_vpnPublicIP2;
              "hub1_vpnBGPIP1" = $hub1_vpnBGPIP1;
              "hub1_vpnBGPIP2" = $hub1_vpnBGPIP2;
              "sharedKey" = $sharedKey
              }


$location=$locationhub1
# Create Resource Group
Write-Host (Get-Date)' - ' -NoNewline
Write-Host 'Creating Resource Group' -ForegroundColor Cyan
Try { Get-AzResourceGroup -Name $rgName -ErrorAction Stop
     Write-Host 'Resource exists, skipping'}
Catch { New-AzResourceGroup -Name $rgName -Location "$location"}

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







