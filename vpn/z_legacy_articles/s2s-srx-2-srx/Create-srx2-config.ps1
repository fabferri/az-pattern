##
## script to generate the configuration of srx2
## the configuration is copied in the clipboard and written in a text file
##
######## Variables
$private_IP_Unstrusted="10.1.1.10/24"          #### private IP of the untrusted interface of srx1, inclusive of subnetmask
$private_IP_Trusted ="10.1.2.10/24"            #### private IP of the trusted interface of srx1, inclusive of subnetmask
$vtiLocal="10.0.200.2"                         #### IP address of the local VTI - WITHOUT subnetmask
$vtiLocalMask="/30"                            #### subnet mask of the local VTI interface
$interface_IP_vti =$vtiLocal+$vtiLocalMask     #### IP address of the local VTI interface inclusive of subnetmask  
$vtiRemote="10.0.200.1"                        #### IP address of the remote VTI interface
$localASN="65002"                              #### BGP local ASN
$remoteASN="65001"                             #### BGP remote ASN
$SharedSecret="Password123!"                   #### shared secret IKE
$gtw_IP_internet="10.1.1.1"                    #### IP address of the gateway subnet of the untrusted interface srx1

$rgName_srx1="srx-01"                          #### resoure group name where is deployed srx2
$location_srx1="easus"                         #### location of the resoure group where is deployed srx1
$vmName_srx1="srx1"                            #### name of the VM srx1
$rgName_srx2="srx-02"                          #### resoure group name where is deployed srx2
$location_srx2="easus"                         #### location of the resoure group where is deployed srx2
$vmName_srx2="srx2"                            #### name of the VM srx2
$pubIPName_srx1="srx1-ge-0-0-0"                #### name of the untrusted interface of the srx1
$pubIPName_srx2="srx2-ge-0-0-0"                #### name of the untrusted interface of the srx2
$fileName="config-srx2.txt"                    #### name of the text file to store the configuration of srx2
################################ 

try {
    Get-AzResourceGroup -Name $rgName_srx1 -Location $location_srx1 -ErrorAction Stop 
} catch {
    Write-Host 'unable to find out the resource group '$rgName_srx1 -foregroundcolor Yellow -backgroundcolor Black
   Exit
}
try {
    Get-AzResourceGroup -Name $rgName_srx2 -Location $location_srx2 -ErrorAction Stop 
} catch {
   Write-Host 'unable to find out the resource group: '$rgName_srx2 -foregroundcolor Yellow -backgroundcolor Black
   Exit
}



try { 
  $pubIP_srx1=(Get-AzPublicIpAddress -ResourceGroupName $rgName_srx1 -Name $pubIPName_srx1 -ErrorAction Stop -WarningAction SilentlyContinue).IpAddress 
} catch
{
   Write-Host 'unable to find out the public IP: '$pubIPName_srx1 -foregroundcolor Yellow -backgroundcolor Black
   Exit
}
try { 
  $pubIP_srx2=(Get-AzPublicIpAddress -ResourceGroupName $rgName_srx2 -Name $pubIPName_srx2 -ErrorAction Stop -WarningAction SilentlyContinue).IpAddress 
} catch
{
   Write-Host 'unable to find out the public IP: '$pubIPName_srx2 -foregroundcolor Yellow -backgroundcolor Black
   Exit
}

# get the public IP od the untrusted interface
write-host "srx1-pub IP:"$pubIP_srx1 -ForegroundColor Yellow -BackgroundColor Black
write-host "srx2-pub IP:"$pubIP_srx2 -ForegroundColor Yellow -BackgroundColor Black



# assign the public IP of untrusted interfaces used in the SRX script
$publicIPUntrustedLocal =$pubIP_srx2
$publicIPUntrustedRemote =$pubIP_srx1


New-Alias Out-Clipboard $env:SystemRoot\System32\Clip.exe -ErrorAction SilentlyContinue
$MyOutput = @"
#Set the IP addresses for vSRX interfaces.
set interfaces ge-0/0/0 unit 0 family inet address $private_IP_Unstrusted
set interfaces ge-0/0/1 unit 0 family inet address $private_IP_Trusted
set interfaces st0 unit 1 description "VPN tunnel"
set interfaces st0 unit 1 family inet address $interface_IP_vti
set interfaces st0 unit 1 family inet mtu 1436

#Set security policy
set security policies from-zone trust to-zone trust policy default-permit match source-address any
set security policies from-zone trust to-zone trust policy default-permit match destination-address any
set security policies from-zone trust to-zone trust policy default-permit match application any
set security policies from-zone trust to-zone trust policy default-permit then permit

set security policies from-zone trust to-zone untrust policy default-permit match source-address any
set security policies from-zone trust to-zone untrust policy default-permit match destination-address any
set security policies from-zone trust to-zone untrust policy default-permit match application any
set security policies from-zone trust to-zone untrust policy default-permit then permit

set security policies from-zone untrust to-zone trust policy default-permit match source-address any
set security policies from-zone untrust to-zone trust policy default-permit match destination-address any
set security policies from-zone untrust to-zone trust policy default-permit match application any
set security policies from-zone untrust to-zone trust policy default-permit then permit

#Set up the untrust security zone.
set security zone security-zone untrust screen untrust-screen
set security zone security-zone untrust host-inbound-traffic system-services all
set security zone security-zone untrust interfaces ge-0/0/0.0


#Set up the trust security zone.
set security zone security-zone trust host-inbound-traffic system-services all
set security zone security-zone trust host-inbound-traffic protocols bgp
set security zone security-zone trust interfaces ge-0/0/1.0
set security zone security-zone trust interfaces st0.1

#Configure IKE.
set security ike proposal ike-phase1-proposalA authentication-method pre-shared-keys
set security ike proposal ike-phase1-proposalA dh-group group2
set security ike proposal ike-phase1-proposalA authentication-algorithm sha-256
set security ike proposal ike-phase1-proposalA encryption-algorithm aes-256-cbc
set security ike proposal ike-phase1-proposalA lifetime-seconds 1800

set security ike policy ike-phase1-policyA mode main
set security ike policy ike-phase1-policyA proposals ike-phase1-proposalA
set security ike policy ike-phase1-policyA pre-shared-key ascii-text $SharedSecret

set security ike gateway gw-siteB ike-policy ike-phase1-policyA
set security ike gateway gw-siteB address $publicIPUntrustedRemote
set security ike gateway gw-siteB local-identity inet $publicIPUntrustedLocal
set security ike gateway gw-siteB external-interface ge-0/0/0.0
set security ike gateway gw-siteB version v2-only
set security ike gateway gw-siteB dead-peer-detection

#Configure IPsec.
set security ipsec proposal ipsec-proposalA protocol esp
set security ipsec proposal ipsec-proposalA authentication-algorithm hmac-sha1-96
set security ipsec proposal ipsec-proposalA encryption-algorithm aes-256-cbc
set security ipsec proposal ipsec-proposalA lifetime-seconds 3600

set security ipsec policy ipsec-policy-siteB proposals ipsec-proposalA

set security ipsec vpn ike-vpn-siteB bind-interface st0.1
set security ipsec vpn ike-vpn-siteB ike gateway gw-siteB
set security ipsec vpn ike-vpn-siteB ike ipsec-policy ipsec-policy-siteB
set security ipsec vpn ike-vpn-siteB establish-tunnels immediately

set security flow tcp-mss ipsec-vpn mss 1387

#Configure routing
set routing-instances siteA-vr1 instance-type virtual-router
set routing-instances siteA-vr1 interface ge-0/0/0.0
set routing-instances siteA-vr1 interface ge-0/0/1.0
set routing-instances siteA-vr1 interface st0.1
set routing-instances siteA-vr1 routing-options static route 0.0.0.0/0 next-hop $gtw_IP_internet


#Configure routing policy to reditribute direct connect networks
set policy-options policy-statement send-direct term 1 from protocol direct
set policy-options policy-statement send-direct term 1 then accept
#set policy-options policy-statement send-direct term 2 from protocol static
#set policy-options policy-statement send-direct term 2 then accept


set routing-instances siteA-vr1 routing-options autonomous-system $localASN
set routing-instances siteA-vr1 routing-options router-id $vtiLocal

set routing-instances siteA-vr1 protocols bgp group ext multihop ttl 5
set routing-instances siteA-vr1 protocols bgp group ext type external

set routing-instances siteA-vr1 protocols bgp group ext export send-direct
set routing-instances siteA-vr1 protocols bgp group ext peer-as $remoteASN
set routing-instances siteA-vr1 protocols bgp group ext local-as $localASN
set routing-instances siteA-vr1 protocols bgp group ext neighbor $vtiRemote 



"@

$MyOutput
$MyOutput | Out-Clipboard

#write the content of the clipboard in a file
$pathFiles = Split-Path -Parent $PSCommandPath
Set-Content -Path "$pathFiles\$fileName" -Value $MyOutput 