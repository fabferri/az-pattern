##### Script to generate the IPSec configuration of Cisco CSR
##### Before running adjust the right value of variables.
#####
#####
$subscriptionName  = "AzDev"        ### name of the Azure subscription where is deployed the VPN Gateway
$rg_vpn            = "rg-vpn"       ### resource group of the VPN Gateway
$vpnName           = "vpnGw"        ### VPN gateway name
$publicIP0_VPN     = "vpnGwIP1"     ### Name of public IP1 assigned to the Azure VPN Gateway
$publicIP1_VPN     = "vpnGwIP2"     ### Name of public IP2 assigned to the Azure VPN Gateway


$subscr=Get-AzSubscription -SubscriptionName $subscriptionName
Select-AzSubscription -SubscriptionId $subscr.Id

try {
 $IP0Gtw=(Get-AzPublicIpAddress -Name $publicIP0_VPN -ResourceGroupName $rg_vpn -ErrorAction Stop).IpAddress
 $IP1Gtw=(Get-AzPublicIpAddress -Name $publicIP1_VPN -ResourceGroupName $rg_vpn -ErrorAction Stop).IpAddress
 write-host "VPN Gateway-public IP0.:"$IP0Gtw -ForegroundColor Yellow -BackgroundColor Black
 write-host "VPN Gateway-public IP1.:"$IP1Gtw -ForegroundColor Yellow -BackgroundColor Black
}
catch{
  write-host "VPN public IP Addresses not found:" -ForegroundColor Yellow 
  write-host " -Check the resource group...:"$rg_vpn   -ForegroundColor Yellow
  write-host " -check the VPN-public IP0...:"$publicIP0_VPN -ForegroundColor Yellow
  write-host " -check the VPN-public IP1...:"$publicIP1_VPN -ForegroundColor Yellow
}
try {
 $gtw=Get-AzVirtualNetworkGateway -Name $vpnName -ResourceGroupName $rg_vpn -ErrorAction stop
 $bgpPeeringIP0,$bgpPeeringIP1 = ($gtw.BgpSettings.BgpPeeringAddress).split(',')
 $bgpRemoteASN= $gtw.BgpSettings.Asn
 write-host "VPN GTW-ASN............: "$bgpRemoteASN -ForegroundColor Yellow -BackgroundColor Black
 write-host "VPN GTW-BGP peering-IP0: "$bgpPeeringIP0 -ForegroundColor Yellow -BackgroundColor Black
 write-host "VPN GTW-BGP peering-IP1: "$bgpPeeringIP1 -ForegroundColor Yellow -BackgroundColor Black
}
catch {
  write-host "VPN gateway not found:" -ForegroundColor Yellow 
  write-host " -Check the resource group...:"$rg_vpn  -ForegroundColor Yellow
  write-host " -check the VNP name.........:"$vpnName -ForegroundColor Yellow
}


######################### PARAMETERS VPN Gateway
$remoteASN=$bgpRemoteASN            # VPN GTW-BGP ASN assigned to the VPN gateway: it is fixed do not changed it!!!
$pubIP_RemoteGtw0=$IP0Gtw           # VPN GTW-public IP address-instance0 of the VPN Gateway
$pubIP_RemoteGtw1=$IP1Gtw           # VPN GTW-public ip address-instance1 of the VPN Gateway 
$remotePeerBGP0=$bgpPeeringIP0      # VPN GTW-BGP peer-instance0 of the VPN Gateway
$remotePeerBGP1=$bgpPeeringIP1      # VPN GTW-BGP peer-instance1 of the VPN Gateway
$PSK="secretPSK101"                 # VPN GTW VPN site-so-site shared secret

######################### PARAMETERS Cisco CSR
$localASN="65011"                   # CSR-BGP ASN
$ip_loopback="172.168.1.1"          # CSR-IP address loopback interface (without SUBNETMASK)
$mask_loopback="255.255.255.255"    # CSR-subnet mask lookback interface (do not change the SUBNETMASK)
$ip_Tunnel0="172.168.0.1"           # CSR-IP ADDRESS of the tunnel0 interface
$mask_Tunnel0="255.255.255.255"     # CSR-SUBNETMASK of the tunnel0 interface (do not change the SUBNETMASK)
$ip_Tunnel1="172.168.0.2"           # CSR-IP ADDRESS of the tunnel1 interface
$mask_Tunnel1="255.255.255.255"     # CSR-subnetmask of the tunnel0 interface (do not change the SUBNETMASK)
$priv_externalNetw="10.1.1.0"       # CSR-private NETWORK PREFIX assigned to the EXTERNAL NIC
$mask_externalNetw="255.255.255.0"  # CSR-mask of private network assigned to the EXTERNAL NIC
$priv_externalGateway="10.1.1.1"    # CSR-IP default gateway of the subnet attached to the EXTERNAL NIC
$priv_internalNetw="10.1.2.0"       # CSR-private NETWORK PREFIX assigned to the INTERNAL NIC
$mask_internalNetw="255.255.255.0"  # CSR-SUBNET MASK of private network assigned to the INTERNAL NIC
#####
$fileName="csr-config.txt"          # filename of output txt file with CSR config



write-host "Remote site1-BGP ASN................: $localASN" -ForegroundColor Cyan
write-host "Remote site1-IP lookback interface..: $ip_loopback $mask_loopback" -ForegroundColor Cyan
write-host "VPN GTW-BGP ASN.....................: $remoteASN" -ForegroundColor Cyan
write-host "VPN GTW public IP Address-instance0.: $pubIP_RemoteGtw0" -ForegroundColor Cyan
write-host "VPN GTW public IP Address-instance1.: $pubIP_RemoteGtw1" -ForegroundColor Cyan
write-host "VPN GTW, BGP peer-instance0.........: $remotePeerBGP0" -ForegroundColor Cyan
write-host "VPN GTW, BGP peer-instance1.........: $remotePeerBGP1" -ForegroundColor Cyan
write-host "VPN GTW, sharedSecret...............: "$PSK -ForegroundColor Cyan


write-host "CSR-ip address of the tunnel0 interface: $ip_Tunnel0 $mask_Tunnel0" -ForegroundColor Green
write-host "CSR-ip address of the tunnel1 interface: $ip_Tunnel1 $mask_Tunnel1" -ForegroundColor Green
write-host "CSR-external network interface.........: $priv_externalNetw $mask_externalNetw" -ForegroundColor Green
write-host "CSR-default gateway external interface.: $priv_externalGateway" -ForegroundColor Green
write-host "CSR-internal network interface.........: $priv_internalNetw $mask_internalNetw" -ForegroundColor Green
write-host "CSR-configuration file.................: $fileName" -ForegroundColor Green
try {
 $choice=Read-Host "are you OK with the input parameters (y/Y)?"
 if ($choice.ToLower() -eq "y") {
   write-host "Create CSR config file"
   }
 } catch {
    write-host "wrong input paramenters"
}


### assembly the configuration of Cisco CSR
$CSRConfig = @"
interface GigabitEthernet2
 ip address dhcp
 no shut
!
interface Loopback0
 ip address $ip_loopback $mask_loopback
 no shut
!
crypto ikev2 proposal az-PROPOSAL
 encryption aes-cbc-256 aes-cbc-128 3des
 integrity sha1
 group 2
!
crypto ikev2 policy az-POLICY
 proposal az-PROPOSAL
!
crypto ikev2 keyring key-peer1
 peer azvpn1
  address $pubIP_RemoteGtw0
  pre-shared-key $PSK
!
!
crypto ikev2 keyring key-peer2
 peer azvpn2
  address $pubIP_RemoteGtw1
  pre-shared-key $PSK
 !
crypto ikev2 profile az-PROFILE1
 match address local interface GigabitEthernet1
 match identity remote address $pubIP_RemoteGtw0 255.255.255.255
 authentication remote pre-share
 authentication local pre-share
 keyring local key-peer1
!
crypto ikev2 profile az-PROFILE2
 match address local interface GigabitEthernet1
 match identity remote address $pubIP_RemoteGtw1 255.255.255.255
 authentication remote pre-share
 authentication local pre-share
 keyring local key-peer2
!
crypto ipsec transform-set az-IPSEC-PROPOSAL-SET esp-aes 256 esp-sha-hmac
 mode tunnel
!
crypto ipsec profile az-VTI1
 set transform-set az-IPSEC-PROPOSAL-SET
 set ikev2-profile az-PROFILE1
!
crypto ipsec profile az-VTI2
 set transform-set az-IPSEC-PROPOSAL-SET
 set ikev2-profile az-PROFILE2
!
interface Tunnel0
 ip address $ip_Tunnel0 $mask_Tunnel0
 ip tcp adjust-mss 1350
 tunnel source GigabitEthernet1
 tunnel mode ipsec ipv4
 tunnel destination $pubIP_RemoteGtw0
 tunnel protection ipsec profile az-VTI1
!
interface Tunnel1
 ip address $ip_Tunnel1 $mask_Tunnel1
 ip tcp adjust-mss 1350
 tunnel source GigabitEthernet1
 tunnel mode ipsec ipv4
 tunnel destination $pubIP_RemoteGtw1
 tunnel protection ipsec profile az-VTI2
!
router bgp $localASN
 bgp router-id interface Loopback0
 bgp log-neighbor-changes
 neighbor $remotePeerBGP0 remote-as $remoteASN
 neighbor $remotePeerBGP0 ebgp-multihop 5
 neighbor $remotePeerBGP0 update-source Loopback0
 neighbor $remotePeerBGP1 remote-as $remoteASN
 neighbor $remotePeerBGP1 ebgp-multihop 5
 neighbor $remotePeerBGP1 update-source Loopback0
 !
 address-family ipv4
  network $priv_internalNetw mask $mask_internalNetw
  network $priv_externalNetw mask $mask_externalNetw
  neighbor $remotePeerBGP0 activate
  neighbor $remotePeerBGP0 next-hop-self
  neighbor $remotePeerBGP0 soft-reconfiguration inbound
  neighbor $remotePeerBGP1 activate
  neighbor $remotePeerBGP1 next-hop-self
  neighbor $remotePeerBGP1 soft-reconfiguration inbound
  maximum-paths eibgp 2
 exit-address-family
!
crypto ikev2 dpd 10 2 on-demand
!
! route set by ARM template
ip route 0.0.0.0 0.0.0.0 $priv_externalGateway
!
!
ip route $remotePeerBGP0 255.255.255.255 Tunnel0
ip route $remotePeerBGP1 255.255.255.255 Tunnel1

line vty 0 4
 exec-timeout 15 0
exit

"@

#write the content of the CSR config in a file
$pathFiles = Split-Path -Parent $PSCommandPath
Set-Content -Path "$pathFiles\$fileName" -Value $CSRConfig 
