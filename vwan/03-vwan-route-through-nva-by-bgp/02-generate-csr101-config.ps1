##### Script to generate the IPSec configuration of Cisco CSR
##### Before running 
##### 
#####

$pubIP_Remotecsr1  = "csr1-pubIP"  ### Name of public IP1 assigned to the remote CSR

$pathFiles  = Split-Path -Parent $PSCommandPath
$templateFile = "$pathFiles\$armTemplateFile"

$pathFiles = Split-Path -Parent $PSCommandPath
$templateFile = "$pathFiles\$armTemplateFile"

# reading the input parameter file $inputParams and convert the values in hashtable 
If (Test-Path -Path $pathFiles\$inputParams) 
{
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
if (!$adminUsername) { Write-Host 'variable $adminUsername is null' ; Exit } else { Write-Host '   administrator username: '$adminUsername -ForegroundColor Green}
if (!$adminPassword) { Write-Host 'variable $adminPassword is null' ; Exit } else { Write-Host '   administrator password: '$adminPassword -ForegroundColor Green}
if (!$subscriptionName) { Write-Host 'variable $subscriptionName is null' ; Exit } else { Write-Host '   subscription name..: '$subscriptionName -ForegroundColor Yellow}
if (!$ResourceGroupName) { Write-Host 'variable $ResourceGroupName is null' ; Exit } else { Write-Host '   resource group name: '$ResourceGroupName -ForegroundColor Yellow}
if (!$hub1location) { Write-Host 'variable $hub1location is null' ; Exit } else { Write-Host '   hub1 location......: '$hub1location -ForegroundColor Yellow}
if (!$hub2location) { Write-Host 'variable $hub2location is null' ; Exit } else { Write-Host '   hub2 location......: '$hub2location -ForegroundColor Yellow}
if (!$branch1location) { Write-Host 'variable $branch1location is null' ; Exit } else { Write-Host '   branch1 location...: '$branch1location -ForegroundColor Yellow}
if (!$branch2location) { Write-Host 'variable $branch2location is null' ; Exit } else { Write-Host '   branch2 location...: '$branch2location -ForegroundColor Yellow}
if (!$hub1Name) { Write-Host 'variable $hub1Name is null' ; Exit } else { Write-Host '   hub1 name..........: '$hub1Name -ForegroundColor Yellow}
if (!$hub2Name) { Write-Host 'variable $hub2Name is null' ; Exit } else { Write-Host '   hub2 name..........: '$hub2Name -ForegroundColor Yellow}
if (!$sharedKey) { Write-Host 'variable $sharedKey is null' ; Exit } else { Write-Host '   sharedKey..........: '$sharedKey -ForegroundColor Yellow}
if (!$mngIP) { Write-Host 'variable $mngIP is null' ; Exit } else { Write-Host '   mngIP..............: '$mngIP -ForegroundColor Yellow}
if (!$RGTagExpireDate) { Write-Host 'variable $RGTagExpireDate is null' ; Exit } else { Write-Host '   RGTagExpireDate....: '$RGTagExpireDate -ForegroundColor Yellow}
if (!$RGTagContact) { Write-Host 'variable $RGTagContact is null' ; Exit } else { Write-Host '   RGTagContact.......: '$RGTagContact -ForegroundColor Yellow}
if (!$RGTagNinja) { Write-Host 'variable $RGTagNinja is null' ; Exit } else { Write-Host '   RGTagNinja.........: '$RGTagNinja -ForegroundColor Yellow}
if (!$RGTagUsage) { Write-Host 'variable $RGTagUsage is null' ; Exit } else { Write-Host '   RGTagUsage.........: '$RGTagUsage -ForegroundColor Yellow}
$rgName=$ResourceGroupName


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


######################### PARAMETERS remote CSR
$remoteASN1='65001'                      # ASN assigned to the remote csr
$pubIP_Remotecsr1=$pubIPRemotecsr1       # public IP address-assigned to the remote csr
$remotePeerBGP1='192.168.0.1'            # remote BGP peer
$remotePrivateExternalIf1='10.0.0.10'    # private external itnerface of the CSR


######################### PARAMETERS Cisco CSR
$PSK=$sharedKey                        # VPN GTW VPN site-so-site shared secret
$localASN="65101"                      # CSR-BGP ASN
$ip_loopback="192.168.0.2"             # CSR-IP address loopback interface (without SUBNETMASK)
$mask_loopback="255.255.255.255"       # CSR-subnet mask lookback interface (do not change the SUBNETMASK)
$ip_Tunnel0="172.16.0.2"               # CSR-IP ADDRESS of the tunnel0 interface
$mask_Tunnel0="255.255.255.252"        # CSR-SUBNETMASK of the tunnel0 interface (do not change the SUBNETMASK)

$priv_externalNetw="10.0.101.0"        # CSR-private NETWORK PREFIX assigned to the EXTERNAL NIC
$mask_externalNetw="255.255.255.192"   # CSR-mask of private network assigned to the EXTERNAL NIC
$priv_defGtwExternal="10.0.101.1"      # CSR-IP default gateway of the subnet attached to the EXTERNAL NIC
$priv_internalNetw1="10.0.101.64"      # CSR-private NETWORK PREFIX assigned to the INTERNAL NIC
$mask_internalNetw1="255.255.255.192"  # CSR-SUBNET MASK of private network assigned to the INTERNAL NIC
$priv_defGtwInternal="10.0.101.65"

$priv_internalNetw2="10.0.101.128"     # private NETWORK PREFIX assigned to the internal subnet not direct connected to the CSR
$mask_internalNetw2="255.255.255.192"  # private MAS assigned to the internal subnet not direct connected to the CSR
#####
$fileName="csr101-config.txt"          # filename of output txt file with CSR config

write-host ""
write-host "Remote csr1-BGP ASN................: $remoteASN1" -ForegroundColor Cyan
write-host "Remote csr1-public IP Address......: $pubIP_Remotecsr1" -ForegroundColor Cyan
write-host "Remote csr1-BGP peer-instance0.....: $remotePeerBGP1" -ForegroundColor Cyan
write-host ""
write-host "local csr-BGP ASN............................: $localASN" -ForegroundColor Green
write-host "local csr-IP lookback interface..............: $ip_loopback $mask_loopback" -ForegroundColor Green
write-host "local csr-ip address of the tunnel0 interface: $ip_Tunnel0 $mask_Tunnel0" -ForegroundColor Green
write-host "local csr-external network interface.........: $priv_externalNetw $mask_externalNetw" -ForegroundColor Green
write-host "local csr-default gateway external interface.: $priv_defGtwExternal" -ForegroundColor Green
write-host "local csr-internal network interface.........: $priv_internalNetw1 $mask_internalNetw1" -ForegroundColor Green
write-host "local csr-default gateway internal interface.: $priv_defGtwInternal" -ForegroundColor Green
write-host "local -second internal network ..............: $priv_internalNetw2 $mask_internalNetw2" -ForegroundColor Green
write-host "local -gateway second internal network.......: $priv_defGtwInternal" -ForegroundColor Green

write-host "local csr-sharedSecret.......................:"$PSK -ForegroundColor Yellow
write-host "local CSR-configuration file.................: $fileName" -ForegroundColor White 
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
!
!
crypto ikev2 profile az-PROFILE1
 match address local interface GigabitEthernet1
 match identity remote address $remotePrivateExternalIf1 255.255.255.255
 authentication remote pre-share
 authentication local pre-share
 keyring local key-peer1
!
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
 tunnel destination $pubIP_Remotecsr1
 tunnel protection ipsec profile az-VTI1
!
!
router bgp $localASN
 bgp router-id interface Loopback0
 bgp log-neighbor-changes
 neighbor $remotePeerBGP1 remote-as $remoteASN1
 neighbor $remotePeerBGP1 ebgp-multihop 3
 neighbor $remotePeerBGP1 update-source Loopback0
 !
 address-family ipv4
  network $priv_internalNetw1 mask $mask_internalNetw1
  network $priv_internalNetw2 mask $mask_internalNetw2
  network $priv_externalNetw mask $mask_externalNetw
  neighbor $remotePeerBGP1 activate
  neighbor $remotePeerBGP1 next-hop-self
  neighbor $remotePeerBGP1 soft-reconfiguration inbound
 exit-address-family
!
crypto ikev2 dpd 10 2 on-demand
!
! route set by ARM template
ip route 0.0.0.0 0.0.0.0 $priv_defGtwExternal
!
!
ip route $remotePeerBGP1 255.255.255.255 Tunnel0
!ip route $priv_internalNetw1 $mask_internalNetw1 $priv_defGtwInternal
ip route $priv_internalNetw2 $mask_internalNetw2 $priv_defGtwInternal

line vty 0 4
 exec-timeout 25 0
exit

"@

#write the content of the CSR config in a file
$pathFiles = Split-Path -Parent $PSCommandPath
Set-Content -Path "$pathFiles\$fileName" -Value $CSRConfig 