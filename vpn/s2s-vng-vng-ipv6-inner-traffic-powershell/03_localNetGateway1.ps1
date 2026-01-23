# Script to create two Local Network Gateways representing on-premises gateway gw1
# The Local network Gateway will be used in gw2 to create the VPN connection
#
$gw1 = "gw1"
$gw1PublicIP1 = "$gw1-pip1"
$gw1PublicIP2 = "$gw1-pip2"

$LocalNetworkGatewayName1 = "lng11"
$LocalNetworkGatewayName2 = "lng12"
$LocalAddressPrefixes = @("10.1.0.0/16", "fd:0:1::/48") 

$pathFiles = Split-Path -Parent $PSCommandPath
$inputParams = 'init.json'
$inputParamsFile = "$pathFiles\$inputParams"

try {
     $arrayParams = (Get-Content -Raw $inputParamsFile | ConvertFrom-Json)
     $subscriptionName = $arrayParams.subscriptionName
     $rgName = $arrayParams.rgName
}
catch {
     Write-Host 'error in reading the parameters file: '$inputParamsFile -ForegroundColor Yellow
     Exit
}

# checking the values of variables
Write-Host "$(Get-Date) - values from file: $inputParams" -ForegroundColor Yellow
if (!$subscriptionName) { Write-Host 'variable $subscriptionName is null' ; Exit }   else { Write-Host '   subscription name.....: '$subscriptionName -ForegroundColor Yellow }
if (!$rgName) { Write-Host 'variable $rgName is null' ; Exit }                       else { Write-Host '   resource group name...: '$rgName -ForegroundColor Yellow }    
if (!$location) { Write-Host 'variable $location is null' ; Exit }                   else { Write-Host '   location..............: '$location -ForegroundColor Yellow }


$subscr = Get-AzSubscription -SubscriptionName $subscriptionName
Select-AzSubscription -SubscriptionId $subscr.Id


$gw1pip1 = (Get-AzPublicIpAddress -Name $gw1PublicIP1 -ResourceGroupName $rgName).IpAddress
$gw1pip2 = (Get-AzPublicIpAddress -Name $gw1PublicIP2 -ResourceGroupName $rgName).IpAddress
$GatewayIpAddress1 = $gw1pip1
$GatewayIpAddress2 = $gw1pip2

Write-Host "$(Get-Date) - Creating Local Network Gateway: "$LocalNetworkGatewayName1 -ForegroundColor Cyan
New-AzLocalNetworkGateway -Name $LocalNetworkGatewayName1 -ResourceGroupName $rgName `
 -Location $location -GatewayIpAddress $GatewayIpAddress1 -AddressPrefix $LocalAddressPrefixes

Write-Host "$(Get-Date) - Creating Local Network Gateway: "$LocalNetworkGatewayName2 -ForegroundColor Cyan
 New-AzLocalNetworkGateway -Name $LocalNetworkGatewayName2 -ResourceGroupName $rgName `
 -Location $location -GatewayIpAddress $GatewayIpAddress2 -AddressPrefix $LocalAddressPrefixes