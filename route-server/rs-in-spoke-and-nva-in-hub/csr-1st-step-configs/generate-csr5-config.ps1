##### Script to generate the IPSec configuration of Cisco CSR
##### Before running 
##### 
#####
$subscriptionName  = "AzDev1"       ### Azure subscription where is deployed the VPN Gateway
$rgName            = "rs03"          ### resource group of the remote VPN Gateway
$pubIP_Remotecsr1  = "csr1-pubIP"  ### Name of public IP1 assigned to the remote CSR
$pubIP_Remotecsr2  = "csr2-pubIP"

$subscr=Get-AzSubscription -SubscriptionName $subscriptionName
Select-AzSubscription -SubscriptionId $subscr.Id

try {
 $pubIPRemotecsr1=(Get-AzPublicIpAddress -Name $pubIP_Remotecsr1 -ResourceGroupName $rgName -ErrorAction Stop).IpAddress
 write-host "public IP:"$pubIPRemotecsr1 -ForegroundColor Yellow -BackgroundColor Black
}
catch{
  write-host "public IP fo remote CSR Addresses not found:" -ForegroundColor Yellow 
  Exit
}
try {
 $pubIPRemotecsr2=(Get-AzPublicIpAddress -Name $pubIP_Remotecsr2 -ResourceGroupName $rgName -ErrorAction Stop).IpAddress
 write-host "public IP:"$pubIPRemotecsr2 -ForegroundColor Yellow -BackgroundColor Black
}
catch{
  write-host "public IP fo remote CSR Addresses not found:" -ForegroundColor Yellow 
  Exit
}

######################### PARAMETERS remote CSR
$remoteASN1='65001'                      # ASN assigned to the remote csr
$pubIP_Remotecsr1=$pubIPRemotecsr1        # public IP address-assigned to the remote csr
$remotePeerBGP1='192.168.0.1'           # remote BGP peer
$remotePrivateExternalIf1='10.101.1.10'    # private external itnerface of the CSR


######################### PARAMETERS remote CSR
$remoteASN2='65002'                       # ASN assigned to the remote csr
$pubIP_Remotecsr2=$pubIPRemotecsr2        # public IP address-assigned to the remote csr
$remotePeerBGP2='192.168.0.2'             # remote BGP peer
$remotePrivateExternalIf2='10.102.1.10'   # private external itnerface of the CSR

######################### PARAMETERS Cisco CSR
$PSK="!secret!PSK!101"               # VPN GTW VPN site-so-site shared secret
$localASN="65005"                    # CSR-BGP ASN
$ip_loopback="192.168.0.5"           # CSR-IP address loopback interface (without SUBNETMASK)
$mask_loopback="255.255.255.255"     # CSR-subnet mask lookback interface (do not change the SUBNETMASK)
$ip_Tunnel0="172.16.0.1"             # CSR-IP ADDRESS of the tunnel0 interface
$mask_Tunnel0="255.255.255.252"      # CSR-SUBNETMASK of the tunnel0 interface (do not change the SUBNETMASK)

$ip_Tunnel1="172.16.0.5"             # CSR-IP ADDRESS of the tunnel0 interface
$mask_Tunnel1="255.255.255.252"      # CSR-SUBNETMASK of the tunnel0 interface (do not change the SUBNETMASK)

$priv_externalNetw="10.5.1.0"        # CSR-private NETWORK PREFIX assigned to the EXTERNAL NIC
$mask_externalNetw="255.255.255.0"   # CSR-mask of private network assigned to the EXTERNAL NIC
$priv_defGtwExternal="10.5.1.1"      # CSR-IP default gateway of the subnet attached to the EXTERNAL NIC
$priv_internalNetw1="10.5.2.0"       # CSR-private NETWORK PREFIX assigned to the INTERNAL NIC
$mask_internalNetw1="255.255.255.0"  # CSR-SUBNET MASK of private network assigned to the INTERNAL NIC
$priv_defGtwInternal="10.5.2.1"

$priv_internalNetw2="10.5.3.0"         # private NETWORK PREFIX assigned to the internal subnet not direct connected to the CSR
$mask_internalNetw2="255.255.255.0"    # private MAS assigned to the internal subnet not direct connected to the CSR
#####
$fileName="csr5-config.txt"          # filename of output txt file with CSR config

write-host ""
write-host "Remote csr1-BGP ASN................: $remoteASN1" -ForegroundColor Cyan
write-host "Remote csr1-public IP Address......: $pubIP_Remotecsr1" -ForegroundColor Cyan
write-host "Remote csr1-BGP peer-instance0.....: $remotePeerBGP1" -ForegroundColor Cyan
write-host ""
write-host "Remote csr2-BGP ASN................: $remoteASN2" -ForegroundColor Cyan
write-host "Remote csr2-public IP Address......: $pubIP_Remotecsr2" -ForegroundColor Cyan
write-host "Remote csr2-BGP peer-instance0.....: $remotePeerBGP2" -ForegroundColor Cyan
write-host ""

write-host "local csr-BGP ASN............................: $localASN" -ForegroundColor Green
write-host "local csr-IP lookback interface..............: $ip_loopback $mask_loopback" -ForegroundColor Green
write-host "local csr-ip address of the tunnel0 interface: $ip_Tunnel0 $mask_Tunnel0" -ForegroundColor Green
write-host "local csr-ip address of the tunnel1 interface: $ip_Tunnel1 $mask_Tunnel1" -ForegroundColor Green
write-host "local csr-external network interface.........: $priv_externalNetw $mask_externalNetw" -ForegroundColor Green
write-host "local csr-default gateway external interface.: $priv_defGtwExternal" -ForegroundColor Green
write-host "local csr-internal network interface.........: $priv_internalNetw1 $mask_internalNetw1" -ForegroundColor Green
write-host "local csr-default gateway internal interface.: $priv_defGtwInternal" -ForegroundColor Green
write-host "local -second internal network ..............: $priv_internalNetw2 $mask_internalNetw2" -ForegroundColor Green
write-host "local -gateway second internal network.......: $priv_defGtwInternal" -ForegroundColor Green

write-host "local csr-sharedSecret.......................:"$PSK -ForegroundColor Cyan
write-host "local CSR-configuration file.................: $fileName" -ForegroundColor Yellow
try {
 $choice=Read-Host "are you OK with the input parameters (y/Y)?"
 if ($choice.ToLower() -eq "y") {
   write-host "Create CSR config file"
   }
 } catch {
    write-host "wrong input parameters"
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
  address $pubIP_Remotecsr1
  pre-shared-key $PSK
!
crypto ikev2 keyring key-peer2
 peer azvpn2
  address $pubIP_Remotecsr2
  pre-shared-key $PSK
!
!
crypto ikev2 profile az-PROFILE1
 match address local interface GigabitEthernet1
 match identity remote address $remotePrivateExternalIf1 255.255.255.255
 authentication remote pre-share
 authentication local pre-share
 keyring local key-peer1
!
crypto ikev2 profile az-PROFILE2
 match address local interface GigabitEthernet1
 match identity remote address $remotePrivateExternalIf2 255.255.255.255
 authentication remote pre-share
 authentication local pre-share
 keyring local key-peer2
!
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
!
interface Tunnel0
 ip address $ip_Tunnel0 $mask_Tunnel0
 ip tcp adjust-mss 1350
 tunnel source GigabitEthernet1
 tunnel mode ipsec ipv4
 tunnel destination $pubIP_Remotecsr1
 tunnel protection ipsec profile az-VTI1
!
interface Tunnel1
 ip address $ip_Tunnel1 $mask_Tunnel1
 ip tcp adjust-mss 1350
 tunnel source GigabitEthernet1
 tunnel mode ipsec ipv4
 tunnel destination $pubIP_Remotecsr2
 tunnel protection ipsec profile az-VTI2
!
!
router bgp $localASN
 bgp router-id interface Loopback0
 bgp log-neighbor-changes
 neighbor $remotePeerBGP1 remote-as $remoteASN1
 neighbor $remotePeerBGP1 ebgp-multihop 3
 neighbor $remotePeerBGP1 update-source Loopback0
 neighbor $remotePeerBGP2 remote-as $remoteASN2
 neighbor $remotePeerBGP2 ebgp-multihop 3
 neighbor $remotePeerBGP2 update-source Loopback0
 !
 address-family ipv4
  network $priv_internalNetw1 mask $mask_internalNetw1
  network $priv_internalNetw2 mask $mask_internalNetw2
  network $priv_externalNetw mask $mask_externalNetw
  neighbor $remotePeerBGP1 activate
  neighbor $remotePeerBGP1 next-hop-self
  neighbor $remotePeerBGP1 soft-reconfiguration inbound
  neighbor $remotePeerBGP2 activate
  neighbor $remotePeerBGP2 next-hop-self
  neighbor $remotePeerBGP2 soft-reconfiguration inbound
 exit-address-family
!
crypto ikev2 dpd 10 2 on-demand
!
! route set by ARM template
ip route 0.0.0.0 0.0.0.0 $priv_defGtwExternal
!
!
ip route $remotePeerBGP1 255.255.255.255 Tunnel0
ip route $remotePeerBGP2 255.255.255.255 Tunnel1
!ip route $priv_internalNetw1 $mask_internalNetw1 $priv_defGtwInternal
ip route $priv_internalNetw2 $mask_internalNetw2 $priv_defGtwInternal

line vty 0 4
 exec-timeout 25 0
exit

"@

#write the content of the CSR config in a file
$pathFiles = Split-Path -Parent $PSCommandPath
Set-Content -Path "$pathFiles\$fileName" -Value $CSRConfig 
