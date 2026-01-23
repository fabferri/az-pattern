##### Script to generate the IPSec configuration of Cisco CSR
##### Before running 
##### 
#####

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
    Write-Output $message
    Try { New-Variable -Name $key -Value $hash[$key] -ErrorAction Stop }
    Catch { Set-Variable -Name $key -Value $hash[$key] }
  }
} 
else { Write-Warning "$inputParams file not found, please change to the directory where these scripts reside ($pathFiles) and ensure this file is present."; Return }

# checking the values of variables
Write-Host "$(Get-Date) - values from file: $inputParams" -ForegroundColor Yellow
if (!$subscriptionName) { Write-Host 'variable $subscriptionName is null' ; Exit }   else { Write-Host '   subscription name..: '$subscriptionName -ForegroundColor Yellow }
if (!$ResourceGroupName) { Write-Host 'variable $ResourceGroupName is null' ; Exit } else { Write-Host '   resource group name: '$ResourceGroupName -ForegroundColor Yellow }
if (!$location1) { Write-Host 'variable $location1 is null' ; Exit }                 else { Write-Host '   location1..........: '$location1 -ForegroundColor Yellow }
if (!$location2) { Write-Host 'variable $location2 is null' ; Exit }                 else { Write-Host '   location2..........: '$location2 -ForegroundColor Yellow }
if (!$csr1Name) { Write-Host 'variable $csr1Name is null' ; Exit }                   else { Write-Host '   csr1Name...........: '$csr1Name -ForegroundColor Yellow }
if (!$csr2Name) { Write-Host 'variable $csr2Name is null' ; Exit }                   else { Write-Host '   csr2Name...........: '$csr2Name -ForegroundColor Yellow }
if (!$sharedKey) { Write-Host 'variable $sharedKey is null' ; Exit }                 else { Write-Host '   sharedKey..........: '$sharedKey -ForegroundColor Yellow }
if (!$adminUsername) { Write-Host 'variable $adminUsername is null' ; Exit }         else { Write-Host '   administrator username: '$adminUsername -ForegroundColor Green }
if (!$adminPassword) { Write-Host 'variable adminPassword is null' ; Exit }          else { Write-Host '   administrator password: 'adminPassword -ForegroundColor Green }
if (!$mngIP) { Write-Host 'variable $mngIP is null'  } else { Write-Host '   mngIP.................: '$mngIP -ForegroundColor Cyan }
$rgName=$ResourceGroupName



$subscr=Get-AzSubscription -SubscriptionName $subscriptionName
Select-AzSubscription -SubscriptionId $subscr.Id

$csr1_pubIPName = $csr1Name + "-pubIP1"
$csr2_pubIPName = $csr2Name + "-pubIP1"
$csr1_nic0Name = $csr1Name + "-nic0"
$csr2_nic0Name = $csr2Name + "-nic0"

try {
  $csr1PubIP=(Get-AzPublicIpAddress -Name $csr1_pubIPName -ResourceGroupName $rgName).IpAddress.ToString()
  $csr2PubIP=(Get-AzPublicIpAddress -Name $csr2_pubIPName -ResourceGroupName $rgName).IpAddress.ToString()
}
catch {
  write-host "csr-public IPs not found:" -ForegroundColor Yellow 
  Exit
}

try {
  $csr1privIP=(Get-AzNetworkInterface -Name $csr1_nic0Name -ResourceGroupName $rgName).IpConfigurations[0].PrivateIpAddress.ToString()
  $csr2privIP=(Get-AzNetworkInterface -Name $csr2_nic0Name -ResourceGroupName $rgName).IpConfigurations[0].PrivateIpAddress.ToString()
}
catch {
  write-host "csr-public IPs not found:" -ForegroundColor Yellow 
  Exit
}

Write-Host "csr1-public IP:"$csr1PubIP
Write-Host "csr2-public IP:"$csr2PubIP

Write-Host "csr1-private IP:"$csr1privIP
Write-Host "csr2-private IP:"$csr2privIP



$remotecsr2ASN = '65002'
$remotecsr2PubIP1 = $csr2PubIP
$remotecsr2PrivIP1 = $csr2privIP
######################### PARAMETERS Cisco CSR
$PSK = $sharedKey                        # VPN GTW VPN site-so-site shared secret
$localASN = '65001'                      # CSR-BGP ASN
$ip_loopback = '192.168.0.1'             # CSR-IP address loopback interface (without SUBNETMASK)
$mask_loopback = '255.255.255.255'       # CSR-subnet mask lookback interface (do not change the SUBNETMASK)

$ip_Tunnel1 = '172.16.0.1'               # CSR-IP ADDRESS of the tunnel0 interface
$mask_Tunnel1 = '255.255.255.255'        # CSR-SUBNETMASK of the tunnel0 interface (do not change the SUBNETMASK)


$priv_externalNetw = '10.0.0.0'          # CSR-private NETWORK PREFIX assigned to the EXTERNAL NIC
$mask_externalNetw = '255.255.255.224'   # CSR-mask of private network assigned to the EXTERNAL NIC
$priv_defGtwExternal = '10.0.0.1'        # CSR-IP default gateway of the subnet attached to the EXTERNAL NIC0

$priv_internalNetw1 = '10.0.0.32'        # CSR-private NETWORK PREFIX assigned to the INTERNAL NIC
$mask_internalNetw1 = '255.255.255.224'  # CSR-SUBNET MASK of private network assigned to the INTERNAL NIC
$priv_defGtwInternal = '10.0.0.33'
$priv_internalNetw2 = '10.0.0.64'        # private NETWORK PREFIX assigned to the internal subnet not direct connected to the CSR
$mask_internalNetw2 = '255.255.255.224'  # private MAS assigned to the internal subnet not direct connected to the CSR
$priv_internalNetw3 = '10.0.0.96'        # private NETWORK PREFIX assigned to the internal subnet not direct connected to the CSR
$mask_internalNetw3 = '255.255.255.224'  # private MAS assigned to the internal subnet not direct connected to the CSR

#####
$fileName = "csr1-config.txt"            # filename of output txt file with CSR config

write-host ""
write-host "csr2-Remote BGP ASN.....: "$remotecsr2ASN -ForegroundColor Cyan
write-host "csr2-public IP1 Address.: "$remotecsr2PubIP1 -ForegroundColor Cyan
write-host "csr2-BGPPeer1...........: "$remotecsr2PrivIP1 -ForegroundColor Cyan

write-host ""

write-host "local csr-BGP ASN............................: "$localASN -ForegroundColor Green
write-host "local csr-IP lookback interface..............: "$ip_loopback $mask_loopback -ForegroundColor Green
write-host "local csr-ip address of the tunnel1 interface: "$ip_Tunnel1 $mask_Tunnel1 -ForegroundColor Green
write-host "local csr-external network interface.........: "$priv_externalNetw $mask_externalNetw -ForegroundColor Green
write-host "local csr-default gateway external interface : "$priv_defGtwExternal -ForegroundColor Green
write-host "local csr-internal network interface.........: "$priv_internalNetw1 $mask_internalNetw1 -ForegroundColor Green
write-host "local csr-default gateway internal interface.: "$priv_defGtwInternal -ForegroundColor Green

write-host "local csr-sharedSecret.......................:"$PSK -ForegroundColor Cyan
write-host "local CSR-configuration file.................: $fileName" -ForegroundColor Yellow
try {
  $choice = Read-Host "are you OK with the input parameters (y/Y)?"
  if ($choice.ToLower() -eq "y") {
    write-host "Create CSR config file"
  }
}
catch {
  write-host "wrong input parameters"
}


### assembly the configuration of Cisco CSR
$CSRConfig = @"
interface GigabitEthernet2
 ip address dhcp
 no shut
!
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
crypto ikev2 keyring key-peer11
 peer azvpn1
  address $remotecsr2PubIP1
  pre-shared-key $PSK
!
!
!
crypto ikev2 profile az-PROFILE1
 match address local interface GigabitEthernet1
 match identity remote address $remotecsr2PrivIP1 255.255.255.255
 authentication remote pre-share
 authentication local pre-share
 keyring local key-peer11
!
!
crypto ipsec transform-set az-IPSEC-PROPOSAL-SET esp-aes 256 esp-sha-hmac
 mode tunnel
!
crypto ipsec profile az-VTI1
 set transform-set az-IPSEC-PROPOSAL-SET
 set ikev2-profile az-PROFILE1
!
interface Tunnel1
 ip address $ip_Tunnel1 $mask_Tunnel1
 ip tcp adjust-mss 1350
 tunnel source GigabitEthernet1
 tunnel mode ipsec ipv4
 tunnel destination $remotecsr2PubIP1
 tunnel protection ipsec profile az-VTI1
!
!
router bgp $localASN
 bgp router-id interface Loopback0
 bgp log-neighbor-changes
 neighbor $remotecsr2PrivIP1 remote-as $remotecsr2ASN
 neighbor $remotecsr2PrivIP1 ebgp-multihop 3
 neighbor $remotecsr2PrivIP1 update-source GigabitEthernet1
 !
 address-family ipv4
  network $priv_externalNetw mask $mask_externalNetw
  network $priv_internalNetw1 mask $mask_internalNetw1
  network $priv_internalNetw2 mask $mask_internalNetw2
  network $priv_internalNetw3 mask $mask_internalNetw3
  neighbor $remotecsr2PrivIP1 activate
  neighbor $remotecsr2PrivIP1 next-hop-self
  neighbor $remotecsr2PrivIP1 soft-reconfiguration inbound

 exit-address-family
!
crypto ikev2 dpd 10 2 on-demand
!
! route set by ARM template
!ip route 0.0.0.0 0.0.0.0 $priv_defGtwExternal
!
!
ip route $remotecsr2PrivIP1 255.255.255.255 Tunnel1
ip route $priv_internalNetw2 $mask_internalNetw2 $priv_defGtwInternal
ip route $priv_internalNetw3 $mask_internalNetw3 $priv_defGtwInternal
!
!
line vty 0 4
 exec-timeout 25 0
exit

"@

#write the content of the CSR config in a file
$pathFiles = Split-Path -Parent $PSCommandPath
Set-Content -Path "$pathFiles\$fileName" -Value $CSRConfig 
