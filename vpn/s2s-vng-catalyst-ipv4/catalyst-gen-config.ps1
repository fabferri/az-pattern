##### Script to generate the IPSec configuration of Cisco CSR
##### Before running adjust the right value of variables.
#####
#####
$inputParams = 'init.json'
####################################################
$pathFiles = Split-Path -Parent $PSCommandPath
$inputParamsFile = "$pathFiles\$inputParams"
$trail= Get-Date -Format "yyyy-MM-dd_HH_mm"
$fileName = 'catalyst-' + $trail.ToString() + '.txt'          # filename of output txt file with CSR config

try {
    $arrayParams = (Get-Content -Raw $inputParamsFile | ConvertFrom-Json)
    $subscriptionName = $arrayParams.subscriptionName
    $rgName = $arrayParams.rgName
    $location = $arrayParams.location
    $adminUsername = $arrayParams.adminUsername
    $adminPassword = $arrayParams.adminPassword
    $catalystName = $arrayParams.catalystName
    $sharedKey = $arrayParams.sharedKey
    $vpnGatewayName = $arrayParams.vpnGatewayName
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
if (!$vpnGatewayName) { Write-Host 'variable $vpnGatewayName is null' ; Exit }       else { Write-Host '  vpnGatewayName......: '$vpnGatewayName -ForegroundColor Cyan }

# Collect information 
#   $localGatewayIpAddress1
#   $localGatewayIpAddress2
#   $bgpPeeringAddress1
#   $bgpPeeringAddress2

$subscr = Get-AzSubscription -SubscriptionName $subscriptionName
Select-AzSubscription -SubscriptionId $subscr.Id

try {
    $gateway = Get-AzVirtualNetworkGateway -ResourceGroupName $rgName -Name $vpnGatewayName -ErrorAction Stop
    $publicIP0_VPN = $vpnGatewayName + '-pubIP1'
    $publicIP1_VPN = $vpnGatewayName + '-pubIP2'

    ## $gateway.IpConfigurations | Format-Table Name, PrivateIpAddress, PublicIpAddress, ProvisioningState, Subnet, PrivateIpAllocationMethod, PublicIpAllocationMethod
    write-host "$(Get-Date) - VPN Gateway IP configurations:" -ForegroundColor White -BackgroundColor Black
    $gateway.IpConfigurations | ForEach-Object {
        write-host "   - Name: "$_.Name -ForegroundColor White -BackgroundColor Black
    }

    $gtwIP0 = (Get-AzPublicIpAddress -Name $publicIP0_VPN -ResourceGroupName $rgName -ErrorAction Stop).IpAddress
    $gtwIP1 = (Get-AzPublicIpAddress -Name $publicIP1_VPN -ResourceGroupName $rgName -ErrorAction Stop).IpAddress
    write-host "$(Get-Date) - VPN Gateway-public IP0.:"$gtwIP0 -ForegroundColor Cyan -BackgroundColor Black
    write-host "$(Get-Date) - VPN Gateway-public IP1.:"$gtwIP1 -ForegroundColor Cyan -BackgroundColor Black
}
catch {
    write-host "VPN public IP Addresses not found:" -ForegroundColor Yellow 
    write-host " -Check the resource group...:"$rg_vpn   -ForegroundColor Yellow
    write-host " -check the VPN-public IP0...:"$publicIP0_VPN -ForegroundColor Yellow
    write-host " -check the VPN-public IP1...:"$publicIP1_VPN -ForegroundColor Yellow
}
try {
    $gtw = Get-AzVirtualNetworkGateway -Name $vpnGatewayName -ResourceGroupName $rgName -ErrorAction stop
}
catch {    
    write-host "$(Get-Date) - check the resource group...: "$rg_vpn   -ForegroundColor Yellow
    write-host "$(Get-Date) - check the VPN gateway......: "$vpnGatewayName -ForegroundColor Yellow
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
    write-host "No VPN connections found for the VPN gateway: "$vpnGatewayName -ForegroundColor Yellow
    write-host " -Check the resource group...:"$rg_vpn   -ForegroundColor Yellow
    write-host " -check the VPN gateway......:"$vpnGatewayName -ForegroundColor Yellow
    write-host " -check the VPN connection" -ForegroundColor Yellow
    Exit
}

######################### PARAMETERS VPN Gateway
$pubIP_RemoteGtw0 = $gtwIP0           # VPN GTW-public IP address-instance0 of the VPN Gateway
$pubIP_RemoteGtw1 = $gtwIP1           # VPN GTW-public ip address-instance1 of the VPN Gateway 
$remoteVnetAddressSpace = '10.1.0.0 255.255.255.0'
######################### PARAMETERS Cisco Catalyst
$ip_Tunnel0 = "172.168.0.1"             # Catalyst-IP ADDRESS of the tunnel0 interface
$ip_Tunnel1 = "172.168.0.2"             # Catalyst-IP ADDRESS of the tunnel1 interface
$priv_externalNetw1 = "10.2.0.90"       # Catalyst-private NETWORK PREFIX assigned to the UNTRUSTED NIC
$priv_externalNetw2 = "10.2.0.91"       # Catalyst-private NETWORK PREFIX assigned to the UNTRUSTED NIC
$mask_externalNetw = "255.255.255.224"  # Catalyst-subnet mask of the IP assigned to the UNTRUSTED NIC
$defaultGwUntrustedSubnet = "10.2.0.65"     # Catalyst-IP default gateway of the subnet attached to the EXTERNAL NIC
#####

#####

write-host "VPN GTW public IP Address-instance0.: $pubIP_RemoteGtw0" -ForegroundColor Cyan
write-host "VPN GTW public IP Address-instance1.: $pubIP_RemoteGtw1" -ForegroundColor Cyan
#write-host "VPN GTW, BGP peer-instance0.........: $remotePeerBGP0" -ForegroundColor Cyan
#write-host "VPN GTW, BGP peer-instance1.........: $remotePeerBGP1" -ForegroundColor Cyan
write-host "VPN GTW, sharedSecret-Connection1...: "$psk1 -ForegroundColor Cyan
write-host "VPN GTW, sharedSecret-Connection2...: "$psk2 -ForegroundColor Cyan

write-host "Catalyst- IP address of the tunnel0 interface: $ip_Tunnel0" -ForegroundColor Green
write-host "Catalyst- IP address of the tunnel1 interface: $ip_Tunnel1" -ForegroundColor Green
write-host "Catalyst- default gateway Untrusted Subnet...: $defaultGwUntrustedSubnet" -ForegroundColor Green
write-host "Catalyst- IP address1 Untrusted interface....: $priv_externalNetw1 $mask_externalNetw" -ForegroundColor Green
write-host "Catalyst- IP address2 Untrusted interface....: $priv_externalNetw2 $mask_externalNetw" -ForegroundColor Green

#write-host "Catalyst- internal network interface.........: $priv_internalNetw $mask_internalNetw" -ForegroundColor Green
write-host "Catalyst- configuration file.................: $fileName" -ForegroundColor Green

try {
    $choice = Read-Host "are you OK with the input parameters (y/Y)?"
    if ($choice.ToLower() -eq "y") {
        write-host "Create CSR config file"
    }
}
catch {
    write-host "wrong input paramenters"
}


### assembly the configuration of Cisco CSR
$CatalystConfig = @"
interface GigabitEthernet2
 ip address dhcp
 no shut
!
interface GigabitEthernet3
 ip address $priv_externalNetw1 $mask_externalNetw
 ip address $priv_externalNetw2 $mask_externalNetw secondary
 negotiation auto
 no shut
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
 match address local $priv_externalNetw1
 match identity remote address $pubIP_RemoteGtw0 255.255.255.255
 authentication remote pre-share
 authentication local pre-share
 keyring local az-KEYRING1
 dpd 40 2 on-demand
!
crypto ikev2 profile az-PROFILE2
 match address local $priv_externalNetw2
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
 ip tcp adjust-mss 1350
 tunnel source $priv_externalNetw1
 tunnel mode ipsec ipv4
 tunnel destination $pubIP_RemoteGtw0
 tunnel protection ipsec profile az-IPSEC-PROFILE1
!
interface Tunnel1
 ip address $ip_Tunnel1 255.255.255.255
 ip tcp adjust-mss 1350
 tunnel source $priv_externalNetw2
 tunnel mode ipsec ipv4
 tunnel destination $pubIP_RemoteGtw1
 tunnel protection ipsec profile az-IPSEC-PROFILE2
!
!
crypto ikev2 dpd 10 2 on-demand
!
! route set by ARM template
ip route 10.2.0.96 255.255.255.224 10.2.0.33
ip route  $pubIP_RemoteGtw0 255.255.255.255 $defaultGwUntrustedSubnet
ip route  $pubIP_RemoteGtw1 255.255.255.255 $defaultGwUntrustedSubnet
!
!
ip route $remoteVnetAddressSpace Tunnel0
ip route $remoteVnetAddressSpace Tunnel1

line vty 0 4
 exec-timeout 10 0
exit

"@

Write-Host $CatalystConfig
#write the content of the Catalyst config in a file
$pathFiles = Split-Path -Parent $PSCommandPath
Set-Content -Path "$pathFiles\$fileName" -Value $CatalystConfig 