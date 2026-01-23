# script to create two VPN connections in gw1
#
#
$LocalNetworkGatewayName1 = 'lng21'
$LocalNetworkGatewayName2 = 'lng22'
$Gateway1Name = "gw1"
$ConnectionName1 = "conn11"
$ConnectionName2 = "conn12"

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

# computation of the shared key
# Deterministic - same seed always produces same key
$seed = $subscr.Id +$rgName 
$hash = [System.Security.Cryptography.SHA256]::Create()
$bytes = $hash.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($seed))
$sharedKey = [Convert]::ToBase64String($bytes).Substring(0, 16)  # 16 chars
Write-Host "$(Get-Date) - Computed shared key: "$sharedKey -ForegroundColor Yellow

$gateway1 = Get-AzVirtualNetworkGateway -Name $Gateway1Name -ResourceGroupName $rgName
$localNetw1 = Get-AzLocalNetworkGateway -Name $LocalNetworkGatewayName1 -ResourceGroupName $rgName
$localNetw2 = Get-AzLocalNetworkGateway -Name $LocalNetworkGatewayName2 -ResourceGroupName $rgName

#Create the VPN connection
Write-Host "$(Get-Date) - Creating VPN Connection: "$ConnectionName1 -ForegroundColor Cyan
New-AzVirtualNetworkGatewayConnection -Name $ConnectionName1 -ResourceGroupName $rgName `
 -Location $location -VirtualNetworkGateway1 $gateway1 -LocalNetworkGateway2 $localNetw1 `
 -ConnectionType IPsec -SharedKey $sharedKey
Write-Host "$(Get-Date) - Created VPN Connection: "$ConnectionName1 -ForegroundColor Cyan

#
#Create the VPN connection
Write-Host "$(Get-Date) - Creating VPN Connection: "$ConnectionName2 -ForegroundColor Cyan
New-AzVirtualNetworkGatewayConnection -Name $ConnectionName2 -ResourceGroupName $rgName `
 -Location $location -VirtualNetworkGateway1 $gateway1 -LocalNetworkGateway2 $localNetw2 `
 -ConnectionType IPsec -SharedKey $sharedKey
Write-Host "$(Get-Date) - Created VPN Connection: "$ConnectionName2 -ForegroundColor Cyan