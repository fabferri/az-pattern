##### 
##### Script to generate the IPSec configuration of Cisco CSR1 in siteA
#####
################# Load the value of parameters from init.json file #################
# Load Initialization Variables
$ScriptDir = Split-Path -Parent $PSCommandPath
If (Test-Path -Path $ScriptDir\init.json){
        $content=Get-Content -Raw -Path $ScriptDir\init.json 
}
Else {Write-Warning "init.txt file not found, please change to the directory where these scripts reside ($ScriptDir) and ensure this file is present.";Return}

$json=ConvertFrom-Json -InputObject $content 

if ( $json -ne $null ) 
{
    foreach ($e in $json) 
    {
       if (-not([string]::IsNullOrEmpty($e.siteA))) { Write-Host (Get-Date)' - ' -NoNewline; Write-host "SiteA is not null.OK!" } else { Write-Host "siteA EMPTY" ; Return }
       if (-not([string]::IsNullOrEmpty($e.siteB))) { Write-Host (Get-Date)' - ' -NoNewline; Write-host "SiteB is not null.OK!" } else { Write-Host "siteB EMPTY" ; Return }
    }
}

if ($json.siteA.subscriptionName) { Write-host "siteA-subscription..:"$json.siteA.subscriptionName -ForegroundColor Green } else { Write-Host "siteA-subscription"; Return }
if ($json.siteA.csr1_vmName)      { Write-host "siteA-csr1 name.....:"$json.siteA.csr1_vmName -ForegroundColor Green }      else { Write-Host "siteA-csr1 name EMPTY"; Return }
if ($json.siteA.csr2_vmName)      { Write-host "siteA-csr2 name.....:"$json.siteA.csr2_vmName -ForegroundColor Green }      else { Write-Host "siteA-csr2 name EMPTY"; Return }
if ($json.siteA.adminUsername)    { Write-host "siteA-admin.........:"$json.siteA.adminUsername -ForegroundColor Green }    else { Write-Host "siteA-admin EMPTY"; Return }
if ($json.siteA.adminPassword)    { Write-host "siteA-admin pwd.....:"$json.siteA.adminPassword -ForegroundColor Green }    else { Write-Host "siteA-admin pwd EMPTY"; Return }
if ($json.siteA.location)         { Write-host "siteA-location......:"$json.siteA.location -ForegroundColor Green }         else { Write-Host "siteA-location EMPTY"; Return }
if ($json.siteA.rgName)           { Write-host "siteA-resource group:"$json.siteA.rgName -ForegroundColor Green }           else { Write-Host "siteA-resource group EMPTY"; Return }

if ($json.siteB.subscriptionName) { Write-host "siteB-subscription..:"$json.siteB.subscriptionName -ForegroundColor Cyan }  else { Write-Host "siteB-subscription"; Return }
if ($json.siteB.csr1_vmName)      { Write-host "siteB-csr1 name.....:"$json.siteB.csr1_vmName -ForegroundColor Cyan }       else { Write-Host "siteB-csr1 name EMPTY"; Return }
if ($json.siteB.csr2_vmName)      { Write-host "siteB-csr2 name.....:"$json.siteB.csr2_vmName -ForegroundColor Cyan }       else { Write-Host "siteB-csr2 name EMPTY"; Return }
if ($json.siteB.adminUsername)    { Write-host "siteB-admin.........:"$json.siteB.adminUsername -ForegroundColor Cyan }     else { Write-Host "siteB-admin EMPTY"; Return }
if ($json.siteB.adminPassword)    { Write-host "siteB-admin pwd.....:"$json.siteB.adminPassword -ForegroundColor Cyan }     else { Write-Host "siteB-admin pwd EMPTY"; Return }
if ($json.siteB.location)         { Write-host "siteB-location......:"$json.siteB.location -ForegroundColor Cyan }          else { Write-Host "siteB-location EMPTY"; Return }
if ($json.siteB.rgName)           { Write-host "siteB-resource group:"$json.siteB.rgName -ForegroundColor Cyan }            else { Write-Host "siteB-resource group EMPTY"; Return }
################# End parameters ###################

######################### Azure
$subscriptionName=$json.siteA.subscriptionName      ### name of the Azure subscription with cisco CSR
$rg_csr_Local = $json.siteA.rgName                  ### resource group of the remote CSR
$csrName_Local= $json.siteA.csr1_vmName             ### Name of the local CSR
$pubIPName_csr_Local= $csrName_Local+"-pubIP"       ### Name of public IP assigned to local CSR

$rg_csr_Remote= $json.siteB.rgName                  ### resource group of the remote CSR
$csrName_Remote = $json.siteB.csr1_vmName           ### Name of the remote CSR
$pubIPName_csr_Remote=$csrName_Remote+"-pubIP"      ### Name of public IP assigned to remote CSR


$subscr=Get-AzSubscription -SubscriptionName $subscriptionName
Select-AzSubscription -SubscriptionId $subscr.Id

Try {  
       Get-AzResourceGroup -Name $rg_csr_Local -ErrorAction Stop | Out-Null
       Write-Host (Get-Date)' - ' -NoNewline
       Write-host "check resource group of local CSR:"$rg_csr_Local -ForegroundColor Yellow
      }
Catch {
       Write-Host (Get-Date)' - ' -NoNewline
       Write-host "local CSR resource group does not exist:"$rg_csr_Local -ForegroundColor Yellow
       Return}       
       
Try {
       Get-AzResourceGroup -Name $rg_csr_Remote -ErrorAction Stop | Out-Null
       Write-Host (Get-Date)' - ' -NoNewline
       Write-host "check resource group of remote CSR:"$rg_csr_Remote -ForegroundColor Yellow
      }
Catch {
       Write-Host (Get-Date)' - ' -NoNewline
       Write-host "remote CSR resource group does not exist:"$rg_csr_Remote -ForegroundColor Yellow
       Return}       

try {
 $IPcsr_local=(Get-AzPublicIpAddress -Name $pubIPName_csr_Local -ResourceGroupName $rg_csr_Local -ErrorAction Stop).IpAddress
 $IPCsr_remote=(Get-AzPublicIpAddress -Name $pubIPName_csr_Remote -ResourceGroupName $rg_csr_Remote -ErrorAction Stop).IpAddress
 Write-Host  "local  csr name:"$csrName_Local  " |  csr local-pub IP :"$IPcsr_Local -ForegroundColor Yellow -BackgroundColor Black
 Write-Host  "remote csr name:"$csrName_Remote " |  csr remote-pub IP:"$IPcsr_Remote -ForegroundColor Yellow -BackgroundColor Black

}
catch{
  Write-Host "Error getting CSR public IP Address:" -ForegroundColor Yellow 
  Write-Host " -check the local  CSR-public IP...:"$IPcsr_Local -ForegroundColor Yellow -BackgroundColor Red
  Write-Host " -check the remote CSR-public IP...:"$IPcsr_Remote -ForegroundColor Yellow -BackgroundColor Red
  Return
}

$fileName="csr11-iosxe-cfg.txt"         # filename of output txt file with CSR config
######################### PARAMETERS CSR remote
$remoteASN="65002"                      # remote CSR-BGP ASN assigned to the VPN gateway: it is fixed do not changed it!!!
$pubIP_csrRemote=$IPcsr_Remote          # remote CSR-public IP address-instance0 of the VPN Gateway
$remotePeerBGP0="172.16.1.2"            # remote CSR-BGP peer-instance0 of the VPN Gateway
$privIP_csrRemote ="10.0.2.10"          # remote CSR-private ip address external interface
$PSK="secret*!*PSK101"                  # shared secret site-to-site VPN

######################### PARAMETERS CSR local
$localASN="65001"                       # CSR-BGP ASN
$ip_loopback="172.16.1.1"               # CSR-IP address loopback interface (without SUBNETMASK)
$mask_loopback="255.255.255.255"        # CSR-subnet mask lookback interface (do not change the SUBNETMASK)
$ip_Tunnel0="192.168.0.1"               # CSR-IP ADDRESS of the tunnel0 interface
$mask_Tunnel0="255.255.255.255"         # CSR-SUBNETMASK of the tunnel0 interface (do not change the SUBNETMASK)
$priv_externalNetw="10.0.1.0"           # CSR-private NETWORK PREFIX assigned to the EXTERNAL NIC
$mask_externalNetw="255.255.255.224"    # CSR-mask of private network assigned to the EXTERNAL NIC
$priv_externalGateway="10.0.1.1"        # CSR-IP default gateway of the subnet attached to the EXTERNAL NIC
$priv_internalNetw1="10.0.1.32"         # CSR-private NETWORK PREFIX assigned to the INTERNAL NIC
$mask_internalNetw1="255.255.255.224"   # CSR-SUBNET MASK of private network assigned to the INTERNAL NIC
$priv_internalNetw2="10.0.1.64"         # CSR-private NETWORK PREFIX assigned to the INTERNAL NIC
$mask_internalNetw2="255.255.255.224"   # CSR-SUBNET MASK of private network assigned to the INTERNAL NIC
#####


Write-Host "site-to-site VPN, sharedSecret...............: $PSK" -ForegroundColor Cyan -BackgroundColor Red
Write-Host "remote csr-BGP ASN...........................: $remoteASN" -ForegroundColor Cyan
Write-Host "remote csr-public IP Address0................: $pubIP_csrRemote" -ForegroundColor Cyan
Write-Host "remote csr-BGP peer-instance0................: $remotePeerBGP0" -ForegroundColor Cyan
Write-Host "local csr-BGP ASN............................: $localASN" -ForegroundColor Green
Write-Host "local csr-IP lookback interface..............: $ip_loopback $mask_loopback" -ForegroundColor Green
Write-Host "local csr-ip address of the tunnel0 interface: $ip_Tunnel0 $mask_Tunnel0" -ForegroundColor Green
Write-Host "local csr-external network interface.........: $priv_externalNetw $mask_externalNetw" -ForegroundColor Green
Write-Host "local csr-default gateway external interface.: $priv_externalGateway" -ForegroundColor Green
Write-Host "local csr-internal network interface1........: $priv_internalNetw1 $mask_internalNetw1" -ForegroundColor Green
Write-Host "local csr-internal network interface2........: $priv_internalNetw2 $mask_internalNetw2" -ForegroundColor Green
Write-Host "local csr-configuration file.................: $fileName" -ForegroundColor Green
try {
 $choice=Read-Host "are you OK with the input parameters (y/n)?"
 if ($choice.ToLower() -eq "y") {
   Write-Host ""
   Write-Host (Get-Date)' - ' -NoNewline
   Write-Host "Create CSR config file: $ScriptDir\$fileName" -ForegroundColor Yellow
   } else {Exit}
 } catch {
    Write-Host "wrong input paramenters"
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
crypto ikev2 keyring key-peer1
 peer azvpn1
  address $pubIP_csrRemote
  pre-shared-key $PSK
!
!
crypto ikev2 profile az-PROFILE1
 match address local interface GigabitEthernet1
 match identity remote address $privIP_csrRemote 255.255.255.255
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
 tunnel destination $pubIP_csrRemote
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
  !network $priv_internalNetw1 mask $mask_internalNetw1
  !network $priv_internalNetw2 mask $mask_internalNetw2
  !network $priv_externalNetw mask $mask_externalNetw
  neighbor $remotePeerBGP0 activate
  neighbor $remotePeerBGP0 next-hop-self
  neighbor $remotePeerBGP0 soft-reconfiguration inbound
  !maximum-paths eibgp 2
 exit-address-family
!
crypto ikev2 dpd 10 2 on-demand
!
! route set by ARM template
ip route 0.0.0.0 0.0.0.0 $priv_externalGateway
!
!
ip route $remotePeerBGP0 255.255.255.255 Tunnel0
line vty 0 4
 exec-timeout 20 0
exit

"@

#write the content of the CSR config in a file
Set-Content -Path "$ScriptDir\$fileName" -Value $CSRConfig 