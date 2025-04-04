##
## List of input variables required to run the script.
##
## $subscriptionName = 'NAME_AZURE_SUBSCRIPTION'
## $rgName = 'NAME_OF_RESOURCE_GROUP'
## $location1 = 'LOCATION_VNET1'
## $location2 = 'LOCATION_VNET2'
## $gw1Name= 'NAME_OF_VPN_GATEWAY_IN_VNET1'
## $gw2Name= 'NAME_OF_VPN_GATEWAY_IN_VNET1'
## $gw1IP1Name = 'NAME_PUBLIC_IP_ADDRESS1_VPN_GATEWAY1'
## $gw1IP2Name = 'NAME_PUBLIC_IP_ADDRESS2_VPN_GATEWAY1'
## $gw2IP1Name = 'NAME_PUBLIC_IP_ADDRESS1_VPN_GATEWAY2'
## $gw2IP2Name = 'NAME_PUBLIC_IP_ADDRESS2_VPN_GATEWAY2'
## $asn1 = AUTONOMOUS_SYSTEM_NUMBER_VPN_GTW1
## $asn2 = AUTONOMOUS_SYSTEM_NUMBER_VPN_GTW2
## $localNetwork11Name = 'NAME_LOCAL_NETWORK-VNET1-IP1'
## $localNetwork12Name = 'NAME_LOCAL_NETWORK-VNET1-IP2'
## $localNetwork21Name = 'NAME_LOCAL_NETWORK-VNET2-IP1'
## $localNetwork22Name = 'NAME_LOCAL_NETWORK-VNET2-IP2'
## $conn11Name = 'NAME_CONNECTION_VPNGTW1_publicIP1-to-VPNGTW2_PublicIP1'
## $conn12Name = 'NAME_CONNECTION_VPNGTW1_publicIP2-to-VPNGTW2_PublicIP2'
## $conn21Name = 'NAME_CONNECTION_VPNGTW2_publicIP1-to-VPNGTW1_PublicIP1'
## $conn22Name = 'NAME_CONNECTION_VPNGTW2_publicIP2-to-VPNGTW1_PublicIP2''
## $sharedKey = 'SHARED_SECRET_S2S_VPN'
#

# $inputParams: json file with list of input variables
$inputParams = 'init.json'

$pathFiles = Split-Path -Parent $PSCommandPath
# reading the input parameter file $inputParams and convert the values in hashtable 
If (Test-Path -Path $pathFiles\$inputParams) {
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
        # Write-Output $message
        Try { New-Variable -Name $key -Value $hash[$key] -ErrorAction Stop }
        Catch { Set-Variable -Name $key -Value $hash[$key] }
    }
} 
else { Write-Warning "$inputParams file not found, please change to the directory where these scripts reside ($pathFiles) and ensure this file is present."; Return }

# checking the values of variables
Write-Host "$(Get-Date) - values from file: $inputParams" -ForegroundColor Yellow
if (!$subscriptionName) { Write-Host 'variable $subscriptionName is null' ; Exit }     else { Write-Host '  subscription name.....: '$subscriptionName -ForegroundColor Yellow }
if (!$ResourceGroupName) { Write-Host 'variable $ResourceGroupName is null' ; Exit }   else { Write-Host '  resource group name...: '$ResourceGroupName -ForegroundColor Yellow }
if (!$location1) { Write-Host 'variable $location1 is null' ; Exit }                   else { Write-Host '  location1.............: '$location1 -ForegroundColor Yellow }
if (!$vnet1Name) { Write-Host 'variable $vnet1Name is null' ; Exit }                   else { Write-Host '  vnet1 Name............: '$vnet1Name -ForegroundColor Yellow }
if (!$app1SubnetName) { Write-Host 'variable $app1SubnetName is null' ; Exit }         else { Write-Host '  app1SubnetName........: '$app1SubnetName -ForegroundColor Yellow }
if (!$vnet1Prefix) { Write-Host 'variable $vnet1Prefix is null' ; Exit }               else { Write-Host '  vnet1Prefix...........: '$vnet1Prefix -ForegroundColor Green }
if (!$app1SubnetPrefix) { Write-Host 'variable $app1SubnetPrefix is null' ; Exit }     else { Write-Host '  app1SubnetPrefix......: '$app1SubnetPrefix -ForegroundColor Green }
if (!$gw1SubnetPrefix) { Write-Host 'variable $gw1SubnetPrefix is null' ; Exit }       else { Write-Host '  gw1SubnetPrefix.......: '$gw1SubnetPrefix -ForegroundColor Green }
if (!$gw1Name) { Write-Host 'variable $gw1Name is null' ; Exit }                       else { Write-Host '  gw1Name...............: '$gw1Name -ForegroundColor Yellow }
if (!$location2) { Write-Host 'variable $location2 is null' ; Exit }                   else { Write-Host '  location2.............: '$location2 -ForegroundColor Yellow }
if (!$vnet2Name) { Write-Host 'variable $vnet2Name is null' ; Exit }                   else { Write-Host '  vnet2 Name............: '$vnet2Name -ForegroundColor Yellow }
if (!$app2SubnetName) { Write-Host 'variable $app2SubnetName is null' ; Exit }         else { Write-Host '  app2SubnetName........: '$app2SubnetName -ForegroundColor Yellow }
if (!$vnet2Prefix) { Write-Host 'variable $vnet2Prefix is null' ; Exit }               else { Write-Host '  vnet2Prefix...........: '$vnet2Prefix -ForegroundColor Green }
if (!$app2SubnetPrefix) { Write-Host 'variable $app2SubnetPrefix is null' ; Exit }     else { Write-Host '  app2SubnetPrefix......: '$app2SubnetPrefix -ForegroundColor Green }
if (!$gw2SubnetPrefix) { Write-Host 'variable $gw2SubnetPrefix is null' ; Exit }       else { Write-Host '  gw2SubnetPrefix.......: '$gw2SubnetPrefix -ForegroundColor Green }
if (!$gw2Name) { Write-Host 'variable $gw2Name is null' ; Exit }                       else { Write-Host '  gw2Name...............: '$gw2Name -ForegroundColor Yellow }
if (!$vpnSku) { Write-Host 'variable $vpnSku is null' ; Exit }                         else { Write-Host '  vpnSku................: '$vpnSku -ForegroundColor Yellow }
if (!$asn1) { Write-Host 'variable $asn1 is null' ; Exit }                             else { Write-Host '  asn1..................: '$asn1 -ForegroundColor Yellow }
if (!$asn2) { Write-Host 'variable $asn2 is null' ; Exit }                             else { Write-Host '  asn2..................: '$asn2 -ForegroundColor Yellow }
if (!$sharedKey) { Write-Host 'variable $sharedKey is null' ; Exit }                   else { Write-Host '  sharedKey.............: '$sharedKey -ForegroundColor Yellow }

$rgName = $ResourceGroupName

$gw1IP1Name = $gw1Name + '-pubIP1'
$gw1IP2Name = $gw1Name + '-pubIP2'
$gw2IP1Name = $gw2Name + '-pubIP1'
$gw2IP2Name = $gw2Name + '-pubIP2'

$localNetwork11Name = 'localNetw-gw1-IP1'
$localNetwork12Name = 'localNetw-gw1-IP2'
$localNetwork21Name = 'localNetw-gw2-IP1'
$localNetwork22Name = 'localNetw-gw2-IP2'
$conn11Name = 'conn11-21'
$conn12Name = 'conn12-22'
$conn21Name = 'conn21-11'
$conn22Name = 'conn22-12'

# selection of the Azure subscription
$subscr = Get-AzSubscription -SubscriptionName $subscriptionName
Select-AzSubscription -SubscriptionId $subscr.Id

# login Check
Try {
    Write-Host 'Using Subscription: ' -NoNewline
    Write-Host $((Get-AzContext).Name) -ForegroundColor Green
}
Catch {
    Write-Warning 'You are not logged in. Login and try again!'
    Return
}

$startTime = Get-Date
write-host ""

# getting the Azure VPN Gateway1 and Azure VPN Gateway2
try {
    write-host "$(Get-Date) - getting VPN Gateway: "$gw1Name
    $gw1 = Get-AzVirtualNetworkGateway -Name $gw1Name -ResourceGroupName $rgName
}
catch {
    write-host "$(Get-Date) - VPN Gateway: $gw1Name not found!" -ForegroundColor Yellow
    Exit
}
try {
    write-host "$(Get-Date) - getting VPN Gateway: "$gw2Name
    $gw2 = Get-AzVirtualNetworkGateway -Name $gw2Name -ResourceGroupName $rgName
}
catch {
    write-host "$(Get-Date) - VPN Gateway: $gw2Name not found!" -ForegroundColor Yellow
    Exit
}

try {
    write-host "$(Get-Date) - Azure VPN Gateway1 - getting BGP peering-IP1: "$gw1BGPIP1
    write-host "$(Get-Date) - Azure VPN Gateway1 - getting BGP peering-IP2: "$gw1BGPIP2
    $gw1BGPIP1, $gw1BGPIP2 = (Get-AzVirtualNetworkGateway -Name $gw1Name -ResourceGroupName $rgName).bgpsettings.BGPPeeringAddress.Split(',')
    write-host '$(Get-Date) - Azure VPN Gateway1 BGP peer-IP1:'$gw1BGPIP1 -ForegroundColor Cyan
    write-host '$(Get-Date) - Azure VPN Gateway1 BGP peer-IP2:'$gw1BGPIP2 -ForegroundColor Cyan
}
catch {
    write-host "$(Get-Date) - Azure VPN Gateway1 - error to retrieve BGP peering IPs" -ForegroundColor Yellow
    Exit
}
try {
    write-host "$(Get-Date) - fetch Azure VPN Gateway2 - public IP: "$gw1IP1Name
    $gw1publicIP1 = (Get-AzPublicIpAddress -Name $gw1IP1Name -ResourceGroupName $rgName).IPAddress

    write-host "$(Get-Date) - fetch Azure VPN Gateway2 - public IP: "$gw1IP2Name
    $gw1publicIP2 = (Get-AzPublicIpAddress -Name $gw1IP2Name -ResourceGroupName $rgName).IPAddress

    write-host "$(Get-Date) - Azure VPN Gateway1 public IP1 .: "$gw1publicIP1 -ForegroundColor Cyan
    write-host "$(Get-Date) - Azure VPN Gateway1 public IP2 .: "$gw1publicIP2 -ForegroundColor Cyan
}
catch {
    write-host "$(Get-Date) - Azure VPN Gateway1 - error to retrieve public IPs" -ForegroundColor Yellow
    Exit
}

try {
    write-host "$(Get-Date) - Azure VPN Gateway2 - getting BGP peering-IP1: "$gw2BGPIP1
    write-host "$(Get-Date) - Azure VPN Gateway2 - getting BGP peering-IP2: "$gw2BGPIP2
    $gw2BGPIP1, $gw2BGPIP2 = (Get-AzVirtualNetworkGateway -Name $gw2Name -ResourceGroupName $rgName).bgpsettings.BGPPeeringAddress.Split(',')
    write-host "$(Get-Date) - Azure VPN Gateway2 BGP peer IP1: "$gw2BGPIP1 -ForegroundColor Cyan
    write-host "$(Get-Date) - Azure VPN Gateway2 BGP peer IP2: "$gw2BGPIP2 -ForegroundColor Cyan
}
catch {
    write-host "$(Get-Date) - Azure VPN Gateway2 - error to retrieve BGP peering IPs" -ForegroundColor Yellow
    Exit
}

try {
    write-host "$(Get-Date) - fetch Azure VPN Gateway2 - public IP: "$gw2IP1Name
    $gw2publicIP1 = (Get-AzPublicIpAddress -Name $gw2IP1Name -ResourceGroupName $rgName).IPAddress

    write-host "$(Get-Date) - fetch Azure VPN Gateway2 - public IP: "$gw2IP2Name
    $gw2publicIP2 = (Get-AzPublicIpAddress -Name $gw2IP2Name -ResourceGroupName $rgName).IPAddress
    write-host "$(Get-Date) - Azure VPN Gateway2 public IP1 .: "$gw2publicIP1 -ForegroundColor Cyan
    write-host "$(Get-Date) - Azure VPN Gateway2 public IP2 .: "$gw2publicIP2 -ForegroundColor Cyan
}
catch {
    write-host "$(Get-Date) - Azure VPN Gateway2 - error to retrieve public IPs" -ForegroundColor Yellow
    Exit
}

### Local Network Gateways: VPN Gateway1 [public IP1,BGP peering IP1]
try {
    Write-Host "$(Get-Date) - creating local network gateway: $localNetwork11Name" -ForegroundColor Cyan
    Get-AzLocalNetworkGateway -Name $localNetwork11Name -ResourceGroupName $rgName -ErrorAction Stop
    Write-Host "$(Get-Date) - local network gateway: $localNetwork11Name already exists, skipping"
}
catch {
    $localNetwork11 = New-AzLocalNetworkGateway -Name $localNetwork11Name -ResourceGroupName $rgName -Location $location1 `
        -GatewayIpAddress $gw1publicIP1  -Asn $asn1 -BgpPeeringAddress $gw1BGPIP1
    Write-Host "$(Get-Date) - local network gateway: $localNetwork11Name created" -ForegroundColor Yellow
}

### Local Network Gateways: VPN Gateway1 [public IP2,BGP peering IP2]
try {
    Write-Host "$(Get-Date) - creating local network gateway: "$localNetwork12Name -ForegroundColor Cyan
    Get-AzLocalNetworkGateway -Name $localNetwork12Name -ResourceGroupName $rgName -ErrorAction Stop
    Write-Host "$(Get-Date) - local network gateway: $localNetwork12Name already exists, skipping"
}
catch {
    $localNetwork12 = New-AzLocalNetworkGateway -Name $localNetwork12Name -ResourceGroupName $rgName -Location $location1 `
        -GatewayIpAddress $gw1publicIP2  -Asn $asn1 -BgpPeeringAddress $gw1BGPIP2   
    Write-Host "$(Get-Date) - local network gateway: $localNetwork12Name created"-ForegroundColor Yellow
}

## Local Network Gateways: VPN Gateway2 [public IP1,BGP peering IP1]
try {
    Write-Host "$(Get-Date) - creating local network gateway: "$localNetwork21Name -ForegroundColor Cyan
    Get-AzLocalNetworkGateway -Name $localNetwork21Name -ResourceGroupName $rgName -ErrorAction Stop
    Write-Host "$(Get-Date) - local network gateway: $localNetwork21Name already exists, skipping"
}
catch {
    $localNetwork21 = New-AzLocalNetworkGateway -Name $localNetwork21Name -ResourceGroupName $rgName -Location $location2 `
        -GatewayIpAddress $gw2publicIP1  -Asn $asn2 -BgpPeeringAddress $gw2BGPIP1
    Write-Host "$(Get-Date) - local network gateway: $localNetwork21Name created" -ForegroundColor Yellow
}

## Local Network Gateways: VPN Gateway2 [public IP2,BGP peering IP2]
try {
    Write-Host "$(Get-Date) - creating local network gateway: "$localNetwork22Name -ForegroundColor Cyan
    Get-AzLocalNetworkGateway -Name $localNetwork22Name -ResourceGroupName $rgName -ErrorAction Stop
    Write-Host "$(Get-Date) - local network gateway: $localNetwork22Name already exists, skipping"
}
catch {
    $localNetwork22 = New-AzLocalNetworkGateway -Name $localNetwork22Name -ResourceGroupName $rgName -Location $location2 `
        -GatewayIpAddress $gw2publicIP2  -Asn $asn2 -BgpPeeringAddress $gw2BGPIP2
    Write-Host "$(Get-Date) - local network gateway: $localNetwork22Name created."-ForegroundColor Yellow
}


## Connection VPN Gateway1 -> Local Network21
try {
    Write-Host "$(Get-Date) - creating VPN connection: "$conn11Name -ForegroundColor Cyan
    Get-AzVirtualNetworkGatewayConnection -Name $conn11Name -ResourceGroupName $rgName -ErrorAction Stop
    Write-Host "$(Get-Date) - VPN Connection: $conn11Name already exists, skipping"
}
catch {
    New-AzVirtualNetworkGatewayConnection -Name $conn11Name -ResourceGroupName $rgName `
        -VirtualNetworkGateway1 $gw1 -LocalNetworkGateway2 $localNetwork21 -Location $location1 `
        -ConnectionType IPsec -SharedKey $sharedKey -EnableBGP $True
    Write-Host "$(Get-Date) - VPN Connection: $conn11Name created" -ForegroundColor Yellow
}

## Connection VPN Gateway1 -> Local Network22
try {
    Write-Host "$(Get-Date) - creating VPN connection: "$conn12Name -ForegroundColor Cyan
    Get-AzVirtualNetworkGatewayConnection -Name $conn12Name -ResourceGroupName $rgName -ErrorAction Stop
    Write-Host "$(Get-Date) - VPN Connection: $conn12Name already exists, skipping"
}
catch {
    New-AzVirtualNetworkGatewayConnection -Name $conn12Name -ResourceGroupName $rgName `
        -VirtualNetworkGateway1 $gw1 -LocalNetworkGateway2 $localNetwork22 -Location $location1 `
        -ConnectionType IPsec -SharedKey $sharedKey -EnableBGP $True
    Write-Host "$(Get-Date) - VPN Connection: $conn12Name created" -ForegroundColor Yellow
}

## Connection VPN Gateway2 -> Local Network11
try {
    Write-Host "$(Get-Date) - creating VPN connection: "$conn21Name -ForegroundColor Cyan
    Get-AzVirtualNetworkGatewayConnection -Name $conn21Name -ResourceGroupName $rgName -ErrorAction Stop
    Write-Host "$(Get-Date) - vpn Connection: $conn21Name already exists, skipping"
}
catch {
    New-AzVirtualNetworkGatewayConnection -Name $conn21Name -ResourceGroupName $rgName `
        -VirtualNetworkGateway1 $gw2 -LocalNetworkGateway2 $localNetwork11 -Location $location2 `
        -ConnectionType IPsec -SharedKey $sharedKey -EnableBGP $True
    Write-Host "$(Get-Date) - VPN Connection: $conn21Name created" -ForegroundColor Yellow
}

## Connection VPN Gateway2 -> Local Network12
try {
    Write-Host "$(Get-Date) - creating VPN connection: "$conn22Name -ForegroundColor Cyan
    Get-AzVirtualNetworkGatewayConnection -Name $conn22Name -ResourceGroupName $rgName -ErrorAction Stop
    Write-Host "$(Get-Date) - VPN Connection: $conn22Name already exists, skipping"
}
catch {
    New-AzVirtualNetworkGatewayConnection -Name $conn22Name -ResourceGroupName $rgName `
        -VirtualNetworkGateway1 $gw2 -LocalNetworkGateway2 $localNetwork12 -Location $location2 `
        -ConnectionType IPsec -SharedKey $sharedKey -EnableBGP $True
    Write-Host "$(Get-Date) - VPN Connection: $conn22Name created" -ForegroundColor Yellow
}

Write-Host "$(Get-Date) - setup completed" -ForegroundColor Green
$endTime = Get-Date
$timeDiff = New-TimeSpan $startTime $endTime
$mins = $timeDiff.Minutes
$secs = $timeDiff.Seconds
$runTime = '{0:00}:{1:00} (M:S)' -f $mins, $secs
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Script completed" -ForegroundColor Green
Write-Host "  Time to complete: $runTime"