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

# Create a resource group
Try {
     Write-Host "$(Get-Date) - creating Resource Group: $rgName" -ForegroundColor Cyan
     $rg = Get-AzResourceGroup -Name $rgName -ErrorAction Stop
     Write-Host "$(Get-Date) - resource group: $rgName exists, skipping" 
}
Catch { $rg = New-AzResourceGroup -Name $rgName -Location "$location1" }


# Create Virtual Network
Try {
     Write-Host "$(Get-Date) - Creating Virtual Network: $vnet1Name" -ForegroundColor Cyan
     $vnet1 = Get-AzVirtualNetwork -ResourceGroupName $rgName -Name $vnet1Name -ErrorAction Stop
     Write-Host '  resource exists, skipping'
}
Catch {
     $vnet1 = New-AzVirtualNetwork -ResourceGroupName $rgName -Name $vnet1Name -AddressPrefix $vnet1Prefix -Location $location1
     Write-Host "$(Get-Date) - Created vnet:"$vnet1.Name
} 
try {
     $app1Subnet = Get-AzVirtualNetworkSubnetConfig -Name $app1SubnetName -VirtualNetwork $vnet1 -ErrorAction Stop
     $gtw1Subnet = Get-AzVirtualNetworkSubnetConfig -Name 'GatewaySubnet' -VirtualNetwork $vnet1  -ErrorAction Stop
}
catch {
     # Add Subnets
     Write-Host "$(Get-Date) - Adding subnets: $app1SubnetName , GatewaySubnet" -ForegroundColor Cyan
     Add-AzVirtualNetworkSubnetConfig -Name $app1SubnetName -VirtualNetwork $vnet1 -AddressPrefix $app1SubnetPrefix | Out-Null
     Add-AzVirtualNetworkSubnetConfig -Name 'GatewaySubnet' -VirtualNetwork $vnet1 -AddressPrefix $gw1SubnetPrefix | Out-Null
     Set-AzVirtualNetwork -VirtualNetwork $vnet1 | Out-Null
}

Try {
     Write-Host "$(Get-Date) - creating VPN Gateway1-public IP: $gw1IP1Name" -ForegroundColor Cyan
     $gw1IP1 = Get-AzPublicIpAddress -Name $gw1IP1Name -ResourceGroupName $rgName  -ErrorAction Stop
     Write-Host "$(Get-Date) - VPN Gateway1-Public IP:  $gw1IP1Name  exists, skipping"
}
Catch {
     $gw1IP1 = New-AzPublicIpAddress -Name $gw1IP1Name -ResourceGroupName $rgName -Location $location1 -AllocationMethod Static -Sku Standard
     Write-Host "$(Get-Date) - VPN Gateway1-Public IP: $gw1IP1Name created" -ForegroundColor Green
}
Try {
     Write-Host "$(Get-Date) - creating VPN Gateway1-public IP: $gw1IP2Name" -ForegroundColor Cyan
     $gw1IP2 = Get-AzPublicIpAddress -Name $gw1IP2Name -ResourceGroupName $rgName  -ErrorAction Stop
     Write-Host "$(Get-Date) - VPN Gateway1-Public IP: $gw1IP2Name resource exists, skipping"
}
Catch {
     # Request a public IP address
     $gw1IP2 = New-AzPublicIpAddress -Name $gw1IP2Name -ResourceGroupName $rgName -Location $location1 -AllocationMethod Static -Sku Standard
     Write-Host "$(Get-Date) - VPN Gateway1-Public IP: $gw1IP2Name created" -ForegroundColor Green
}

# Create the gateway IP address configuration
$vnet1 = Get-AzVirtualNetwork -Name $vnet1Name -ResourceGroupName $rgName
$gw1subnet = Get-AzVirtualNetworkSubnetConfig -Name 'GatewaySubnet' -VirtualNetwork $vnet1
$gw1ipconf1 = New-AzVirtualNetworkGatewayIpConfig -Name gw1ipconfig1 -SubnetId $gw1subnet.Id -PublicIpAddressId $gw1IP1.Id
$gw1ipconf2 = New-AzVirtualNetworkGatewayIpConfig -Name gw1ipconfig2 -SubnetId $gw1subnet.Id -PublicIpAddressId $gw1IP2.Id

Try {
     Get-AzVirtualNetworkGateway -Name $gw1Name -ResourceGroupName $rgName -ErrorAction Stop
     Write-Host "$(Get-Date) - VirtualNetworkGateway: $gw1Name  exists, skipping"
}
catch {
     # Create the VPN gateway
     $gw1 = New-AzVirtualNetworkGateway -Name $gw1Name -ResourceGroupName $rgName `
          -Location $location1 -IpConfigurations $gw1ipconf1, $gw1ipconf2 -GatewayType Vpn `
          -VpnType RouteBased -GatewaySku $vpnSku -EnableBgp $true -Asn $asn1 -VpnGatewayGeneration Generation2 -EnableActiveActiveFeature -AsJob
    
     $j = Get-Job -Command 'New-AzVirtualNetworkGateway'
     $status = 'Running'
     write-host "job status:"
     while ($status -eq 'Running') {
          Start-Sleep -Seconds 60
          # $j.Id[-1]  select the last job id
          $status = (Get-Job -Id $j.Id[-1]).State
          write-host "..." -NoNewline
          write-host $status -NoNewline -ForegroundColor Yellow
     } 
}
write-host ""
$gw1pip1 = Get-AzPublicIpAddress -Name $gw1IP1Name -ResourceGroupName $rgName
$gw1pip2 = Get-AzPublicIpAddress -Name $gw1IP2Name -ResourceGroupName $rgName
$gw1 = Get-AzVirtualNetworkGateway -Name $gw1Name -ResourceGroupName $rgName

# Obtain the Azure VPN public IP addresses
$gw1publicIP1 = (Get-AzPublicIpAddress -Name $gw1IP1Name -ResourceGroupName $rgName).IPAddress
$gw1publicIP2 = (Get-AzPublicIpAddress -Name $gw1IP2Name -ResourceGroupName $rgName).IPAddress
write-host 'Azure VPN Gateway public IP1 .:'$gw1publicIP1 -ForegroundColor Cyan
write-host 'Azure VPN Gateway public IP2 .:'$gw1publicIP2 -ForegroundColor Cyan

# Obtain the Azure BGP Peer IP address
$gw1BGPIP1, $gw1BGPIP2 = (Get-AzVirtualNetworkGateway -Name $gw1Name -ResourceGroupName $rgName).bgpsettings.BGPPeeringAddress.Split(',')
write-host 'Azure VPN Gateway BGP peer IP1:'$gw1BGPIP1 -ForegroundColor Cyan
write-host 'Azure VPN Gateway BGP peer IP2:'$gw1BGPIP2 -ForegroundColor Cyan


$endTime = Get-Date
$timeDiff = New-TimeSpan $startTime $endTime
$mins = $timeDiff.Minutes
$secs = $timeDiff.Seconds
$runTime = '{0:00}:{1:00} (M:S)' -f $mins, $secs
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Script completed" -ForegroundColor Green
Write-Host "  Time to complete: $runTime"
