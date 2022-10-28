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
#
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
if (!$adminUsername) { Write-Host 'variable $adminUsername is null' ; Exit }         else { Write-Host '   administrator username: '$adminUsername -ForegroundColor Green}
if (!$adminPassword) { Write-Host 'variable $adminPassword is null' ; Exit }         else { Write-Host '   administrator password: '$adminPassword -ForegroundColor Green}
if (!$subscriptionName) { Write-Host 'variable $subscriptionName is null' ; Exit }   else { Write-Host '   subscription name.....: '$subscriptionName -ForegroundColor Yellow}
if (!$ResourceGroupName) { Write-Host 'variable $ResourceGroupName is null' ; Exit } else { Write-Host '   resource group name...: '$ResourceGroupName -ForegroundColor Yellow}
if (!$vwanName) { Write-Host 'variable $vwanName is null' ; Exit }                   else { Write-Host '   virtual WAN name......: '$vwanName -ForegroundColor Yellow}
if (!$hub1location) { Write-Host 'variable $hub1location is null' ; Exit }           else { Write-Host '   hub1 location.........: '$hub1location -ForegroundColor Yellow}
if (!$hub1Name) { Write-Host 'variable $hub1Name is null' ; Exit }                   else { Write-Host '   hub1 name.............: '$hub1Name -ForegroundColor Yellow}
if (!$branch1location) { Write-Host 'variable $branch1_location is null' ; Exit }    else { Write-Host '   branch1 location......: '$branch1location -ForegroundColor Yellow}
if (!$mngIP) { Write-Host 'variable $mngIP is null' ; Exit }                         else { Write-Host '   mngIP.................: '$mngIP -ForegroundColor Yellow}

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
$hub1 = $hub1Name+'_S2SvpnGW'
$vpnGateway = Get-AzVpnGateway -ResourceGroupName $rgName -Name $hub1
#getting public IPs VPN GTW
#$vWAN_PublicIP1=$vpnGateway.IpConfigurations.PublicIpAddress[0]
#$vWAN_PublicIP2=$vpnGateway.IpConfigurations.PublicIpAddress[1]
#$remotevWAN_BGPIP1=($vpnGateway.BgpSettings.BgpPeeringAddresses[0].DefaultBgpIpAddresses) | Out-String
#$remotevWAN_BGPIP2=($vpnGateway.BgpSettings.BgpPeeringAddresses[1].DefaultBgpIpAddresses) | Out-String


$hub1_vpnPublicIP1 = Out-String -InputObject ($vpnGateway.IpConfigurations.PublicIpAddress[0]) -NoNewline
$hub1_vpnPublicIP2 = Out-String -InputObject ($vpnGateway.IpConfigurations.PublicIpAddress[1]) -NoNewline
$hub1_vpnBGPIP1 = Out-String -InputObject ($vpnGateway.BgpSettings.BgpPeeringAddresses[0].DefaultBgpIpAddresses) -NoNewline
$hub1_vpnBGPIP2 = Out-String -InputObject ($vpnGateway.BgpSettings.BgpPeeringAddresses[1].DefaultBgpIpAddresses) -NoNewline



if (!$hub1_vpnPublicIP1) { Write-Host 'variable $hub1_vpnPublicIP1 is null' ; Exit } else { Write-Host '   vWAN-vpn public IP1....: '$hub1_vpnPublicIP1 -ForegroundColor Cyan}
if (!$hub1_vpnPublicIP2) { Write-Host 'variable $hub1_vpnPublicIP2 is null' ; Exit } else { Write-Host '   vWAN-vpn public IP2....: '$hub1_vpnPublicIP2 -ForegroundColor Cyan}
if (!$hub1_vpnBGPIP1) { Write-Host 'variable $hub1_vpnBGPIP1 is null' ; Exit } else { Write-Host '   vWAN-vpn remote BGP IP1: '$hub1_vpnBGPIP1 -ForegroundColor Cyan}
if (!$hub1_vpnBGPIP2) { Write-Host 'variable $hub1_vpnBGPIP2 is null' ; Exit } else { Write-Host '   vWAN-vpn remote BGP IP2: '$hub1_vpnBGPIP2 -ForegroundColor Cyan}


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



$startTime = Get-Date
write-host "$startTime - running ARM template: "$templateFile -ForegroundColor Cyan
New-AzResourceGroupDeployment  -Name $deploymentName -ResourceGroupName $rgName -TemplateFile $templateFile -TemplateParameterObject $parameters -Verbose 

$endTime = Get-Date 
Write-Host "$endTime - setup completed" -ForegroundColor Green

$timeDiff = New-TimeSpan $startTime $endTime
$mins = $timeDiff.Minutes
$secs = $timeDiff.Seconds
$runTime = '{0:00}:{1:00} (M:S)' -f $mins, $secs
Write-Host "$(Get-Date) - Script completed" -ForegroundColor Green
Write-Host "Time to complete: "$runTime
