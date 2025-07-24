##### Script to generate the IPSec configuration of Cisco CSR
##### Before running adjust the right value of variables.
#####
#####
$inputParams = 'init.json'
####################################################
$pathFiles = Split-Path -Parent $PSCommandPath
$inputParamsFile = "$pathFiles\$inputParams"

try {
    $arrayParams = (Get-Content -Raw $inputParamsFile | ConvertFrom-Json)
    $subscriptionName = $arrayParams.subscriptionName
    $rgName = $arrayParams.rgName
    $location = $arrayParams.location
    $adminUsername = $arrayParams.adminUsername
    $adminPassword = $arrayParams.adminPassword
    $catalystName = $arrayParams.catalystName
    $sharedKey = $arrayParams.sharedKey
    $gatewayName = $arrayParams.gatewayName
}
catch {
    Write-Host 'error in reading the parameters file: '$inputParamsFile -ForegroundColor Yellow
    Exit
}

 
# checking the values of variables from init.json
Write-Host "$(Get-Date) - values from file: $inputParams" -ForegroundColor Yellow
if (!$subscriptionName) { Write-Host 'variable $subscriptionName is null' ; Exit }   else { Write-Host '  subscription name...: '$subscriptionName -ForegroundColor Yellow }
if (!$rgName) { Write-Host 'variable $rgName is null' ; Exit }                       else { Write-Host '  resource group......: '$rgName -ForegroundColor Yellow }
if (!$location) { Write-Host 'variable $location is null' ; Exit }                   else { Write-Host '  location............: '$location -ForegroundColor Yellow }
if (!$adminUsername) { Write-Host 'variable $adminUsername is null' ; Exit }         else { Write-Host '  adminUsername.......: '$adminUsername -ForegroundColor Red }
if (!$adminPassword) { Write-Host 'variable $adminPassword is null' ; Exit }         else { Write-Host '  adminPassword.......: '$adminPassword -ForegroundColor Red }
if (!$catalystName) { Write-Host 'variable $catalystName is null' ; Exit }           else { Write-Host '  catalystName........: '$catalystName -ForegroundColor Cyan }
if (!$sharedKey) { Write-Host 'variable $sharedKey is null' ; Exit }                 else { Write-Host '  sharedKey...........: '$sharedKey -ForegroundColor Cyan }
if (!$gatewayName) { Write-Host 'variable $gatewayName is null' ; Exit }             else { Write-Host '  gatewayName.........: '$gatewayName -ForegroundColor Cyan }

# Collect information 
#   $localGatewayIpAddress1
#   $localGatewayIpAddress2
#   $bgpPeeringAddress1
#   $bgpPeeringAddress2

$subscr = Get-AzSubscription -SubscriptionName $subscriptionName
Select-AzSubscription -SubscriptionId $subscr.Id

try {
    $gateway = Get-AzVirtualNetworkGateway -ResourceGroupName $rgName -Name $gatewayName -ErrorAction Stop
    $publicIP0_VPN = $gatewayName + '-pubIP1'
    $publicIP1_VPN = $gatewayName + '-pubIP2'

    ## $gateway.IpConfigurations | Format-Table Name, PrivateIpAddress, PublicIpAddress, ProvisioningState, Subnet, PrivateIpAllocationMethod, PublicIpAllocationMethod
    write-host "$(Get-Date) - VPN Gateway IP configurations:" -ForegroundColor White -BackgroundColor Black
    $gateway.IpConfigurations | ForEach-Object {
        write-host "   - Name: "$_.Name -ForegroundColor White -BackgroundColor Black
    }

    $gtwIP0 = (Get-AzPublicIpAddress -Name $publicIP0_VPN -ResourceGroupName $rgName -ErrorAction Stop).IpAddress
    $gtwIP1 = (Get-AzPublicIpAddress -Name $publicIP1_VPN -ResourceGroupName $rgName -ErrorAction Stop).IpAddress
    write-host "$(Get-Date) - VPN Gateway-public IP0.: "$gtwIP0 -ForegroundColor Cyan -BackgroundColor Black
    write-host "$(Get-Date) - VPN Gateway-public IP1.: "$gtwIP1 -ForegroundColor Cyan -BackgroundColor Black
}
catch {
    write-host "VPN public IP Addresses not found:" -ForegroundColor Yellow 
    write-host " -Check the resource group...: "$rgName   -ForegroundColor Yellow
    write-host " -check the VPN-public IP0...: "$publicIP0_VPN -ForegroundColor Yellow
    write-host " -check the VPN-public IP1...: "$publicIP1_VPN -ForegroundColor Yellow
}
try {
    $gtw = Get-AzVirtualNetworkGateway -Name $gatewayName -ResourceGroupName $rgName -ErrorAction stop
}
catch {    
    write-host "$(Get-Date) - check the resource group...: "$rgName   -ForegroundColor Yellow
    write-host "$(Get-Date) - check the VPN gateway......: "$gatewayName -ForegroundColor Yellow
    Exit
}

$connList = Get-AzVirtualNetworkGatewayConnection -ResourceGroupName $rgName  -ErrorAction stop
if ($connList.Count -gt 0) {
    $connName1 = $ConnList[0].Name
    $connName2 = $ConnList[1].Name
    # get the PSK for the VPN connections
    write-host "$(Get-Date) - VPN GTW-connection1....: "$connName1 -ForegroundColor Green -BackgroundColor Black
    write-host "$(Get-Date) - VPN GTW-connection2....: "$connName2 -ForegroundColor Green -BackgroundColor Black
    $psk1 = Get-AzVirtualNetworkGatewayConnectionSharedKey -ResourceGroupName $rgName -Name $connName1
    $psk2 = Get-AzVirtualNetworkGatewayConnectionSharedKey -ResourceGroupName $rgName -Name $connName2
    write-host "$(Get-Date) - VPN GTW-sharedKey1.....: "$psk1 -ForegroundColor Yellow -BackgroundColor Black
    write-host "$(Get-Date) - VPN GTW-sharedKey2.....: "$psk2 -ForegroundColor Yellow -BackgroundColor Black
}
else {
    write-host "No VPN connections found for the VPN gateway: "$gatewayName -ForegroundColor Yellow
    write-host " -Check the resource group...:"$rgName   -ForegroundColor Yellow
    write-host " -check the VPN gateway......:"$gatewayName -ForegroundColor Yellow
    write-host " -check the VPN connection" -ForegroundColor Yellow
    Exit
}

try {
    # collect the Catalyst-IPv4 private NETWORK PREFIX assigned to the eth1 NIC
    $nic_eth1 = Get-AzNetworkInterface -ResourceGroupName $rgName -Name "$catalystName-eth1-nic"
    $priv_eth1IP = $nic_eth1.IpConfigurations[0].PrivateIpAddress
    write-host "Catalyst eth1 private IPv4: "$priv_eth1IP -ForegroundColor Cyan

    # collect the Catalyst-IPv6 private NETWORK PREFIX assigned to the eth1 NIC
    $priv_eth1IPv6 = $nic_eth1.IpConfigurations[1].PrivateIpAddress
    write-host "Catalyst eth1 private IPv6: "$priv_eth1IPv6 -ForegroundColor Cyan
    write-host " "

    # collect the Catalyst-IPv4 private NETWORK PREFIX assigned to the eth2 NIC
    $nic_eth2 = Get-AzNetworkInterface -ResourceGroupName $rgName -Name "$catalystName-eth2-nic"
    $priv_eth2IP = $nic_eth2.IpConfigurations[0].PrivateIpAddress
    write-host "Catalyst eth2 private IPv4: "$priv_eth2IP -ForegroundColor Cyan

    # collect the Catalyst-IPv6 private NETWORK PREFIX assigned to the eth2 NIC
    $priv_eth2IPv6 = $nic_eth2.IpConfigurations[1].PrivateIpAddress
    write-host "Catalyst eth2 private IPv6: "$priv_eth2IPv6 -ForegroundColor Cyan
    write-host " "

    # collect the Catalyst-IPv4 private NETWORK PREFIX assigned to the eth3 NIC
    $nic_eth3 = Get-AzNetworkInterface -ResourceGroupName $rgName -Name "$catalystName-eth3-nic"
    $priv_eth3IP = $nic_eth3.IpConfigurations[0].PrivateIpAddress
    write-host "Catalyst eth3 private IPv4: "$priv_eth3IP -ForegroundColor Cyan

    # collect the Catalyst-IPv6 private NETWORK PREFIX assigned to the eth3 NIC
    $priv_eth3IPv6 = $nic_eth3.IpConfigurations[1].PrivateIpAddress
    write-host "Catalyst eth3 private IPv6: "$priv_eth3IPv6 -ForegroundColor Cyan
    write-host " "
}
catch {
    write-host "No Network Interface found for the Catalyst: "$catalystName -ForegroundColor Yellow
    write-host " -Check the resource group...:"$rgName   -ForegroundColor Yellow
    write-host " -check the Catalyst name....:"$catalystName -ForegroundColor Yellow
    Exit
}

try{
# Define the virtual network name and subnet name
$vnetName = 'cat-net'
$subnetName = 'app-subnet'

# Get the virtual network object
$vnet = Get-AzVirtualNetwork -Name $vnetName -ResourceGroupName $rgName -ErrorAction Stop

# Get the subnet configuration
$subnetConfig = Get-AzVirtualNetworkSubnetConfig -Name $subnetName -VirtualNetwork $vnet

# Display the subnet address prefix
Write-Host "Subnet Name: $($subnetConfig.Name)"
Write-Host "Address Prefix IPv4: $($subnetConfig.AddressPrefix[0])"
Write-Host "Address Prefix IPv6: $($subnetConfig.AddressPrefix[1])"
} 
catch {
    write-host "No Subnet in the vnet.....: "$vnetName -ForegroundColor Yellow
    write-host " -check the resource group: "$rgName   -ForegroundColor Yellow
    write-host " -check the subnet name...: "$subnetName -ForegroundColor Yellow
    Exit
}

######################### PARAMETERS VPN Gateway
$pubIP_RemoteGtw0 = $gtwIP0              # VPN GTW-public IPv4 address assigned to the VPN Gateway-instance_0
$pubIP_RemoteGtw1 = $gtwIP1              # VPN GTW-public IPv4 address assigned to the VPN Gateway-instance_1 
$remoteVnetAddressSpaceIPv4 = '10.1.0.0 255.255.255.0' # IPv4 address space of the remote vnet1
$remoteVnetAddressSpaceIPv6 = '2001:db8:1::/48'        # IPv6 address space of the remote vnet1
######################### PARAMETERS Cisco Catalyst
$ip_Tunnel0 = '172.168.0.1'              # Catalyst-IPv4 address of the tunnel0 interface
$ip_Tunnel1 = '172.168.0.2'              # Catalyst-IPv4 address of the tunnel1 interface
# $priv_eth2IP                           # Catalyst-IPv4 private network prefix assigned to the eth2 NIC
# $priv_eth3IP                           # Catalyst-IPv4 private network prefix assigned to the eth3 NIC
$mask_eth2 = '255.255.255.224'           # Catalyst-IPv4 subnet mask assigned to the eth2 NIC
$mask_eth3 = '255.255.255.224'           # Catalyst-IPv4 subnet mask assigned to the eth3 NIC
$defaultGwEth1Subnet = '10.2.0.1'        # Catalyst-IPv4 default gateway of the subnet attached to the eth1 NIC
$defaultGwEth2Subnet = '10.2.0.33'       # Catalyst-IPv4 default gateway of the subnet attached to the eth2 NIC
$defaultGwEth3Subnet = '10.2.0.65'       # Catalyst-IPv4 default gateway of the subnet attached to the eth3 NIC
$internalSubnetIPv4 = '10.2.0.96'            # Catalyst-IPv4 app-subnet in vnet2
$internalSubnetMaskIPv4 = '255.255.255.224'  # Catalyst-IPv4 subnet mask of the app-subnet in vnet2

# variables to set the IPv6 static routes to the app-subnet in vnet2
$internalSubnetIPv6 = '2001:db8:2:4::'       # Catalyst-IPv6 address of the app-subnet in vnet2
$internalSubnetMaskIPv6 = '/64'              # Catalyst-IPv6 subnet mask of the app-subnet in vnet2
$defaultGwEth1SubnetIPv6 = '2001:db8:2:1::1' # Catalyst-IPv6 default gateway of the subnet attached to the eth1 NIC
#####
$currDatetime = (Get-Date).ToString("yyyyMMdd_HHmmss")
$fileName = "catalyst-$currDatetime.txt"          # filename of output txt file with Catalyst config
#####

write-host "VPN GTW public IP Address-instance0.: $pubIP_RemoteGtw0" -ForegroundColor Cyan
write-host "VPN GTW public IP Address-instance1.: $pubIP_RemoteGtw1" -ForegroundColor Cyan
write-host "VPN GTW, sharedSecret-Connection1...: "$psk1 -ForegroundColor Cyan
write-host "VPN GTW, sharedSecret-Connection2...: "$psk2 -ForegroundColor Cyan

write-host "Catalyst- IP address of the tunnel0 interface: $ip_Tunnel0" -ForegroundColor Green
write-host "Catalyst- IP address of the tunnel1 interface: $ip_Tunnel1" -ForegroundColor Green
write-host "Catalyst- default gateway Eth1 Subnet........: $defaultGwEth1Subnet" -ForegroundColor Green
write-host "Catalyst- default gateway Eth2 Subnet........: $defaultGwEth2Subnet" -ForegroundColor Green
write-host "Catalyst- default gateway Eth3 Subnet........: $defaultGwEth3Subnet" -ForegroundColor Green
write-host "Catalyst- eth2 private IP....................: $priv_eth2IP $mask_eth2" -ForegroundColor Green
write-host "Catalyst- eth3 private IP....................: $priv_eth3IP $mask_eth3" -ForegroundColor Green

#write-host "Catalyst- internal network interface.........: $priv_internalNetw $mask_internalNetw" -ForegroundColor Green
write-host "Catalyst- configuration file.................: $fileName" -ForegroundColor Green

try {
    $choice = Read-Host "are you OK with the input parameters (y/Y)?"
    if ($choice.ToLower() -eq "y") {
        write-host "Create CSR config file"
    } 
    else{
        Exit
    }
}
catch {
    write-host "wrong input paramenters"
}


### assembly the configuration of Cisco CSR
$CatalystConfig = @"
!
ipv6 unicast-routing
!
interface GigabitEthernet1
 ip address dhcp
 ip nat outside
 negotiation auto
 ipv6 address dhcp
 ipv6 enable
 ipv6 nd autoconfig default-route
 no mop enabled
 no mop sysid
!
interface GigabitEthernet2
 ip address dhcp
 negotiation auto
 ipv6 address dhcp
 ipv6 enable
 ipv6 nd autoconfig default-route
 no mop enabled
 no mop sysid
 no shut
!
interface GigabitEthernet3
 ip address dhcp
 negotiation auto
 ipv6 address dhcp
 ipv6 enable
 ipv6 nd autoconfig default-route
 no mop enabled
 no mop sysid
 no shut
!
!
crypto ikev2 proposal az-PROPOSAL
 encryption aes-gcm-256 aes-gcm-128
 prf sha384 sha256
 group 14
!
crypto ikev2 policy az-POLICY
 proposal az-PROPOSAL
!
crypto ikev2 keyring az-KEYRING1
 peer az-gw-instance0
  address $pubIP_RemoteGtw0
  pre-shared-key $psk1
!
!
crypto ikev2 keyring az-KEYRING2
 peer az-gw-instance1
  address $pubIP_RemoteGtw1
  pre-shared-key $psk2
 !
crypto ikev2 profile az-PROFILE1
 match address local $priv_eth2IP
 match identity remote address $pubIP_RemoteGtw0 255.255.255.255
 authentication remote pre-share
 authentication local pre-share
 keyring local az-KEYRING1
 dpd 40 2 on-demand
!
crypto ikev2 profile az-PROFILE2
 match address local $priv_eth3IP
 match identity remote address $pubIP_RemoteGtw1 255.255.255.255
 authentication remote pre-share
 authentication local pre-share
 keyring local az-KEYRING2
 dpd 40 2 on-demand
!
crypto ipsec transform-set az-TRANSFORMSET esp-gcm 256
 mode tunnel
!
crypto ipsec profile az-IPSEC-PROFILE1
 set transform-set az-TRANSFORMSET
 set ikev2-profile az-PROFILE1
!
crypto ipsec profile az-IPSEC-PROFILE2
 set transform-set az-TRANSFORMSET
 set ikev2-profile az-PROFILE2
!
interface Tunnel0
 ip address $ip_Tunnel0 255.255.255.255
 ipv6 enable
 ip tcp adjust-mss 1350
 tunnel source $priv_eth2IP
 tunnel mode ipsec dual-overlay
 tunnel destination $pubIP_RemoteGtw0
 tunnel protection ipsec profile az-IPSEC-PROFILE1
!
interface Tunnel1
 ip address $ip_Tunnel1 255.255.255.255
 ipv6 enable
 ip tcp adjust-mss 1350
 tunnel source $priv_eth3IP
 tunnel mode ipsec dual-overlay
 tunnel destination $pubIP_RemoteGtw1
 tunnel protection ipsec profile az-IPSEC-PROFILE2
!
!
ip route $remoteVnetAddressSpaceIPv4 Tunnel0
ip route $remoteVnetAddressSpaceIPv4 Tunnel1
ip route $pubIP_RemoteGtw0 255.255.255.255 $defaultGwEth2Subnet
ip route $pubIP_RemoteGtw1 255.255.255.255 $defaultGwEth3Subnet
ip route $internalSubnetIPv4 $internalSubnetMaskIPv4 $defaultGwEth1Subnet
ipv6 route $internalSubnetIPv6$internalSubnetMaskIPv6 $defaultGwEth1SubnetIPv6
ipv6 route $remoteVnetAddressSpaceIPv6 Tunnel0
ipv6 route $remoteVnetAddressSpaceIPv6 Tunnel1
!
!
line vty 0 4
 exec-timeout 10 0
exit

"@

Write-Host $CatalystConfig
#write the content of the Catalyst config in a file
$pathFiles = Split-Path -Parent $PSCommandPath
Set-Content -Path "$pathFiles\$fileName" -Value $CatalystConfig 