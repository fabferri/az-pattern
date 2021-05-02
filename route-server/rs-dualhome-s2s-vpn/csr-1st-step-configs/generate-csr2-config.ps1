##### Script to generate the IPSec configuration of Cisco CSR
##### Before running 
##### 
#####
$subscriptionName  = "AzDev1"       ### Azure subscription where is deployed the VPN Gateway
$rgName            = "rs03"         ### resource group of the remote VPN Gateway
$pubIP_remotecsr   = "csr5-pubIP"  ### Name of public IP1 assigned to the remote CSR

$subscr=Get-AzSubscription -SubscriptionName $subscriptionName
Select-AzSubscription -SubscriptionId $subscr.Id

try {
 $pubIPRemotecsr=(Get-AzPublicIpAddress -Name $pubIP_remotecsr -ResourceGroupName $rgName -ErrorAction Stop).IpAddress
 write-host "public IP:"$pubIPRemotecsr -ForegroundColor Yellow -BackgroundColor Black
}
catch{
  write-host "public IP fo remote CSR Addresses not found:" -ForegroundColor Yellow 
  Exit
}


######################### remote Cisco CSR
$remoteASN='65005'                     # ASN assigned to the remote csr
$pubIP_Remotecsr=$pubIPRemotecsr       # public IP address-assigned to the remote CSR
$remotePeerBGP0='192.168.0.5'          # remote BGP peer
$remotePrivateExternalIf='10.5.1.10'   # private external interface of the CSR

######################### local Cisco CSR
$PSK="!secret!PSK!101"                 # site-to-site VPN shared secret
$localASN="65002"                      # CSR-BGP ASN
$ip_loopback="192.168.0.2"             # CSR-IP address loopback interface (without SUBNETMASK)
$mask_loopback="255.255.255.255"       # CSR-subnet mask lookback interface (do not change the SUBNETMASK)
$ip_Tunnel0="172.16.0.6"               # CSR-IP ADDRESS of the tunnel0 interface
$mask_Tunnel0="255.255.255.252"          # CSR-SUBNETMASK of the tunnel0 interface (do not change the SUBNETMASK)
$priv_externalNetw="10.102.1.0"          # CSR-private NETWORK PREFIX assigned to the EXTERNAL NIC
$mask_externalNetw="255.255.255.0"     # CSR-mask of private network assigned to the EXTERNAL NIC
$priv_defGtwExternal="10.102.1.1"        # CSR-default gateway of the subnet attached to the EXTERNAL NIC
$priv_internalNetw1="10.102.2.0"         # CSR-private NETWORK PREFIX assigned to the INTERNAL NIC
$mask_internalNetw1="255.255.255.0"    # CSR-SUBNET MASK of private network assigned to the INTERNAL NIC
$priv_defGtwInternal="10.102.2.1"        # CSR-default gateway of the subnet attached to the INTERNAL NIC
$priv_internalNetw2="10.102.3.0"         # private NETWORK PREFIX assigned to the internal subnet not direct connected to the CSR
$mask_internalNetw2="255.255.255.0"      # private MAS assigned to the internal subnet not direct connected to the CSR																																 

####
$fileName="csr2-config.txt"            # filename of output txt file with CSR config

write-host ""
write-host "Remote csr-BGP ASN................: $remoteASN" -ForegroundColor Cyan
write-host "Remote csr-public IP Address......: $pubIP_Remotecsr" -ForegroundColor Cyan
write-host "Remote csr-BGP peer-instance0.....: $remotePeerBGP0" -ForegroundColor Cyan

write-host "local csr-BGP ASN............................: $localASN" -ForegroundColor Cyan
write-host "local csr-IP lookback interface..............: $ip_loopback $mask_loopback" -ForegroundColor Cyan
write-host "local csr-ip address of the tunnel0 interface: $ip_Tunnel0 $mask_Tunnel0" -ForegroundColor Green
write-host "local csr-external network ..................: $priv_externalNetw $mask_externalNetw" -ForegroundColor Green
write-host "local csr-default gateway external interface.: $priv_defGtwExternal" -ForegroundColor Green
write-host "local csr-internal network ..................: $priv_internalNetw1 $mask_internalNetw1" -ForegroundColor Green
write-host "local csr-default gateway internal interface.: $priv_defGtwInternal" -ForegroundColor Green																														 
write-host "local -second internal network ..............: $priv_internalNetw2 $mask_internalNetw2" -ForegroundColor Green
write-host "local -gateway second internal network.......: $priv_defGtwInternal" -ForegroundColor Green
write-host "local csr-sharedSecret.......................:"$PSK -ForegroundColor Cyan
write-host "local CSR-configuration file.................: $fileName" -ForegroundColor Green
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
  address $pubIP_Remotecsr
  pre-shared-key $PSK
!
!
crypto ikev2 profile az-PROFILE1
 match address local interface GigabitEthernet1
 match identity remote address $remotePrivateExternalIf 255.255.255.255
 authentication remote pre-share
 authentication local pre-share
 keyring local key-peer1
!
!
crypto ipsec transform-set az-IPSEC-PROPOSAL-SET esp-aes 256 esp-sha-hmac
 mode tunnel
!
crypto ipsec profile az-VTI1
 set transform-set az-IPSEC-PROPOSAL-SET
 set ikev2-profile az-PROFILE1
!
!
interface Tunnel0
 ip address $ip_Tunnel0 $mask_Tunnel0
 ip tcp adjust-mss 1350
 tunnel source GigabitEthernet1
 tunnel mode ipsec ipv4
 tunnel destination $pubIP_Remotecsr
 tunnel protection ipsec profile az-VTI1
!
!
router bgp $localASN
 bgp router-id interface Loopback0
 bgp log-neighbor-changes
 neighbor $remotePeerBGP0 remote-as $remoteASN
 neighbor $remotePeerBGP0 ebgp-multihop 5
 neighbor $remotePeerBGP0 update-source Loopback0
 !
 address-family ipv4
  network $priv_internalNetw1 mask $mask_internalNetw1
  network $priv_internalNetw2 mask $mask_internalNetw2													  
  network $priv_externalNetw mask $mask_externalNetw
  neighbor $remotePeerBGP0 activate
  neighbor $remotePeerBGP0 next-hop-self
  neighbor $remotePeerBGP0 soft-reconfiguration inbound
 exit-address-family
!
crypto ikev2 dpd 10 2 on-demand
!
! route set by ARM template
ip route 0.0.0.0 0.0.0.0 $priv_defGtwExternal
!
!
ip route $remotePeerBGP0 255.255.255.255 Tunnel0
!ip route $priv_internalNetw1 $mask_internalNetw1 $priv_defGtwInternal
ip route $priv_internalNetw2 $mask_internalNetw2 $priv_defGtwInternal																	 


line vty 0 4
 exec-timeout 25 0
exit

"@

#write the content of the CSR config in a file
$pathFiles = Split-Path -Parent $PSCommandPath
Set-Content -Path "$pathFiles\$fileName" -Value $CSRConfig 
