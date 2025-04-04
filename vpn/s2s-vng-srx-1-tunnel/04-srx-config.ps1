## script to generate the SRX configuration
## the configuration is written in a text file
#
######## Collect variables from init.json file
$armTemplateParametersFile = 'init.json'
####################################################
$pathFiles = Split-Path -Parent $PSCommandPath
$parametersFile = "$pathFiles\$armTemplateParametersFile"

try {
    $arrayParams = (Get-Content -Raw $parametersFile | ConvertFrom-Json)
    $subscriptionName = $arrayParams.subscriptionName
    $resourceGroupName = $arrayParams.resourceGroupName
    $location = $arrayParams.location
    $location1 = $arrayParams.location1
    $location1 = $arrayParams.location1
    $location2 = $arrayParams.location2
    $gatewayName = $arrayParams.gatewayName
    $srxName = $arrayParams.srxName
    $adminUsername = $arrayParams.adminUsername
    $adminPassword = $arrayParams.adminPassword
    Write-Host "$(Get-Date) - values from file: "$parametersFile -ForegroundColor Yellow
    if (!$subscriptionName) { Write-Host 'variable $subscriptionName is null' ; Exit }      else { Write-Host '   subscriptionName......: '$subscriptionName -ForegroundColor Yellow }
    if (!$resourceGroupName) { Write-Host 'variable $resourceGroupName is null' ; Exit }    else { Write-Host '   resourceGroupName.....: '$resourceGroupName -ForegroundColor Yellow }
    if (!$location) { Write-Host 'variable $location is null' ; Exit }                      else { Write-Host '   location..............: '$location -ForegroundColor Yellow }
    if (!$location1) { Write-Host 'variable $location1 is null' ; Exit }                    else { Write-Host '   location1.............: '$location1 -ForegroundColor Yellow }
    if (!$location2) { Write-Host 'variable $location2 is null' ; Exit }                    else { Write-Host '   location2.............: '$location2 -ForegroundColor Yellow }
    if (!$gatewayName) { Write-Host 'variable $gatewayName is null' ; Exit }                else { Write-Host '   gatewayName...........: '$gatewayName -ForegroundColor Cyan }
    if (!$srxName) { Write-Host 'variable $srxName is null' ; Exit }                        else { Write-Host '   srxName...............: '$srxName -ForegroundColor Cyan }
    if (!$adminUsername) { Write-Host 'variable $adminUsername is null' ; Exit }            else { Write-Host '   administrator username: '$adminUsername -ForegroundColor Green }
    if (!$adminPassword) { Write-Host 'variable $adminPassword is null' ; Exit }            else { Write-Host '   administrator password: '$adminPassword -ForegroundColor Green }
} 
catch {
    Write-Host 'error in reading the template file: '$parametersFile -ForegroundColor Yellow
    Exit
}

######## Variables
$srx__Unstrusted_privIP ='10.200.0.5/27'        #### private IP of the untrusted interface of srx, inclusive of subnetmask
$srx_Trusted_privIP ='10.200.0.50/27'           #### private IP of the trusted interface of srx, inclusive of subnetmask
$srx_Untrusted_IPgtw ='10.200.0.1'              #### IP address of the gateway of the srx untrusted interface
$vtiLocal ='172.16.0.1/32'                      #### IP address of the local VTI inclusive of subnetmask

$vtiRemote ='10.100.0.126'                      #### IP address of the VPN Gateway BGP IP addreewss - without subnet mask
$localASN ='65002'                              #### BGP local ASN
$remoteASN ='65001'                             #### BGP remote ASN
$sharedSecret =''                               #### shared secret IKE

$srx_rgName = $resourceGroupName                #### resoure group name where is deployed srx
$srx_location = $location2                      #### location of the resoure group where is deployed srx
$vpngw_rgName = $resourceGroupName              #### resoure group name where is deployed the VPN Gateway
$vpngw_location = $location1                    #### location of the resoure group where is deployed the VPN Gateway
$srx_Unstrusted_pubIPName =$srxName+'-ge-0-0-0' #### public IP name the SRX untrusted interface
$vpnGw_pubIPName =$gatewayName +'-IP1'          #### public IP name of the VPN Gateway

$srx_internalSubnet1= '10.200.0.96/27'          #### subnet1 belonging to the vnet where is deployed the SRX
$srx_gtwIP_internalSubnet1='10.200.0.33'        #### IP address of the gateway to reach out from the SRX the subnet1

$fileName ='config_srx.txt'                     #### name of the text file to store the configuration of srx2

################################ 
# removing subnetmask from SRX virtual tunnel interface
$pos = $vtiLocal.IndexOf("/")
$vtiLocalIP = $vtiLocal.Substring(0, $pos)
$connectionName = $gatewayName + '-to-'+ $srxName

try {
   $vpngw = Get-AzVirtualNetworkGateway -Name $gatewayName -ResourceGroupName $vpngw_rgName -ErrorAction Stop -WarningAction SilentlyContinue
} catch {
   Write-Host 'unable to find out the  VPN Gateway: '$gatewayName -foregroundcolor Yellow -backgroundcolor Black
   Exit
}

try {
   $vtiRemote = (Get-AzVirtualNetworkGateway -Name $gatewayName -ResourceGroupName $vpngw_rgName -ErrorAction Stop -WarningAction SilentlyContinue).BgpSettings.BgpPeeringAddress
} catch {
   Write-Host 'unable to find out the BGP IP of the VPN Gateway: '$gatewayName -foregroundcolor Yellow -backgroundcolor Black
   Exit
}

try {
   $sharedSecret = Get-AzVirtualNetworkGatewayConnectionSharedKey -ResourceGroupName $resourceGroupName -Name $connectionName
} catch {
   Write-Host 'unable to find out S2S shared key ' -foregroundcolor Yellow -backgroundcolor Black
  Exit
}

try {
    Get-AzResourceGroup -Name $srx_rgName -Location $srx_location -ErrorAction Stop 
} catch {
    Write-Host 'unable to find out the resource group: '$srx_rgName -foregroundcolor Yellow -backgroundcolor Black
   Exit
}
try {
   Get-AzResourceGroup -Name $vpngw_rgName -Location $vpngw_location -ErrorAction Stop 
} catch {
   Write-Host 'unable to find out the resource group: '$vpngw_rgName -foregroundcolor Yellow -backgroundcolor Black
  Exit
}


try { 
  $srx_untrusted_pubIP=(Get-AzPublicIpAddress -ResourceGroupName $srx_rgName -Name $srx_Unstrusted_pubIPName -ErrorAction Stop -WarningAction SilentlyContinue).IpAddress 
} catch
{
   Write-Host 'unable to find out the public IP of the untrusted SRX interface: '$srx_Unstrusted_pubIPName -foregroundcolor Yellow -backgroundcolor Black
   Exit
}
try { 
  $vpnGtw_pubIP=(Get-AzPublicIpAddress -ResourceGroupName $vpngw_rgName -Name $vpnGw_pubIPName -ErrorAction Stop -WarningAction SilentlyContinue).IpAddress 
} catch
{
   Write-Host 'unable to find out the public IP of the VPN Gateway: '$vpnGw_pubIPName -foregroundcolor Yellow -backgroundcolor Black
   Exit
}


# SRX public IP of the untrusted interface
# VpN Gateway public IP 
write-host 'vpn gateway- BGP IP Address..: '$vtiRemote -ForegroundColor Yellow -BackgroundColor Black
write-host 'vpn gateway- pubIP...........: '$vpnGtw_pubIP -ForegroundColor Yellow -BackgroundColor Black
write-host 'srx untrusted interface-pubIP: '$srx_Untrusted_pubIP -ForegroundColor Yellow -BackgroundColor Black
write-host 'srx - vti IP address.........: '$vtiLocalIP -ForegroundColor Yellow -BackgroundColor Black
write-host 'shared key...................: '$sharedSecret -ForegroundColor Yellow -BackgroundColor Black
write-host ''

$MyOutput = @"
# Set the IP addresses for vSRX Virtual Firewall interfaces.
set interfaces ge-0/0/0 unit 0 family inet address $srx__Unstrusted_privIP
set interfaces ge-0/0/1 unit 0 family inet address $srx_Trusted_privIP
set interfaces st0 unit 0 family inet address $vtiLocal

# define the security zone an association of interfaces to security zones.
set security zones security-zone untrust interfaces ge-0/0/0.0 host-inbound-traffic system-services ike
set security zones security-zone untrust interfaces ge-0/0/0.0 host-inbound-traffic protocols bgp
set security zones security-zone untrust interfaces st0.0 host-inbound-traffic system-services ping
set security zones security-zone untrust interfaces st0.0 host-inbound-traffic protocols bgp

# Set up the trust security zone.
set security zones security-zone trust interfaces ge-0/0/1.0 host-inbound-traffic system-services all
set security zones security-zone trust interfaces ge-0/0/1.0 host-inbound-traffic protocols all

# Set security policy
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


#PHASE 1
set security ike proposal VPN_AZURE_IKE_PROPOSAL authentication-method pre-shared-keys
set security ike proposal VPN_AZURE_IKE_PROPOSAL dh-group group2
set security ike proposal VPN_AZURE_IKE_PROPOSAL encryption-algorithm aes-256-cbc
set security ike proposal VPN_AZURE_IKE_PROPOSAL authentication-algorithm sha-256
set security ike proposal VPN_AZURE_IKE_PROPOSAL lifetime-seconds 28800
set security ike policy VPN_AZURE_IKE_POLICY mode main
set security ike policy VPN_AZURE_IKE_POLICY proposals VPN_AZURE_IKE_PROPOSAL
set security ike policy VPN_AZURE_IKE_POLICY pre-shared-key ascii-text $sharedSecret
set security ike gateway VPN_AZURE_IKE_GW ike-policy VPN_AZURE_IKE_POLICY
set security ike gateway VPN_AZURE_IKE_GW address $vpnGtw_pubIP
set security ike gateway VPN_AZURE_IKE_GW dead-peer-detection
set security ike gateway VPN_AZURE_IKE_GW local-identity inet $srx_Untrusted_pubIP
set security ike gateway VPN_AZURE_IKE_GW remote-identity inet $vpnGtw_pubIP
set security ike gateway VPN_AZURE_IKE_GW external-interface ge-0/0/0.0
set security ike gateway VPN_AZURE_IKE_GW version v2-only

#PHASE 2
set security ipsec proposal VPN_AZURE_IPSEC_PROPOSAL protocol esp
set security ipsec proposal VPN_AZURE_IPSEC_PROPOSAL authentication-algorithm hmac-sha1-96
set security ipsec proposal VPN_AZURE_IPSEC_PROPOSAL encryption-algorithm aes-256-cbc
set security ipsec proposal VPN_AZURE_IPSEC_PROPOSAL lifetime-seconds 28800
set security ipsec policy VPN_AZURE_IPSEC_POLICY proposals VPN_AZURE_IPSEC_PROPOSAL
set security ipsec vpn VPN_AZURE bind-interface st0.0
set security ipsec vpn VPN_AZURE ike gateway VPN_AZURE_IKE_GW
set security ipsec vpn VPN_AZURE ike ipsec-policy VPN_AZURE_IPSEC_POLICY
set security ipsec vpn VPN_AZURE establish-tunnels immediately


# Configure routing
set routing-instances siteA-vr1 instance-type virtual-router
set routing-instances siteA-vr1 interface ge-0/0/0.0
set routing-instances siteA-vr1 interface ge-0/0/1.0
set routing-instances siteA-vr1 interface st0.0

#Routing Configurations to Reach remote BGP/tunnel ip
set routing-instances siteA-vr1 routing-options static route $vtiRemote/32 next-hop st0.0
set routing-instances siteA-vr1 routing-options static route $srx_internalSubnet1 next-hop $srx_gtwIP_internalSubnet1
set routing-instances siteA-vr1 routing-options static route 0.0.0.0/0 next-hop $srx_Untrusted_IPgtw


# Configure routing policy to reditribute direct connect networks and static routes. 
# The name of routing policy in case is "send-direct" 
set policy-options policy-statement send-direct term 1 from protocol direct
set policy-options policy-statement send-direct term 1 then accept
set policy-options policy-statement send-direct term 2 from protocol static
set policy-options policy-statement send-direct term 2 from route-filter $srx_internalSubnet1 orlonger
set policy-options policy-statement send-direct term 2 then accept


# BGP Configurations
set routing-instances siteA-vr1 routing-options autonomous-system $localASN
set routing-instances siteA-vr1 routing-options router-id $vtiLocalIP
set routing-instances siteA-vr1 protocols bgp group azure type external
set routing-instances siteA-vr1 protocols bgp group azure multihop ttl 50
set routing-instances siteA-vr1 protocols bgp group azure export send-direct

set routing-instances siteA-vr1 protocols bgp group azure peer-as $remoteASN
set routing-instances siteA-vr1 protocols bgp group azure neighbor $vtiRemote
set routing-instances siteA-vr1 protocols bgp local-address $vtiLocalIP

"@

$MyOutput

#write the content of the clipboard in a file
$pathFiles = Split-Path -Parent $PSCommandPath
Set-Content -Path "$pathFiles\$fileName" -Value $MyOutput 