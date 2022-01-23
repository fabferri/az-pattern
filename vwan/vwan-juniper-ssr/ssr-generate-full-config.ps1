##### Script to generate the IPSec configuration of Cisco CSR
##### Before running 
##### 
#####
####################################################
$inputParams = 'init.json'
$r1MngName = 'r1-mgmt'
$r1PubName = 'r1-public'
$r1PrivName = 'r1-private'

$r2MngName = 'r2-mgmt'
$r2PubName = 'r2-public'
$r2PrivName = 'r2-private'

$r3MngName = 'r3-mgmt'
$r3PubName = 'r3-public'
$r3PrivName = 'r3-private'

$r1_nicMng_vmbusId  = '000d3a6c-e3c6-000d-3a6c-e3c6000d3a6c'
$r1_nicPub_vmbusId  = '000d3a6c-ed37-000d-3a6c-ed37000d3a6c'
$r1_nicPriv_vmbusId = '000d3a6c-e668-000d-3a6c-e668000d3a6c'

$r2_nicMng_vmbusId =  '000d3a6c-e374-000d-3a6c-e374000d3a6c'
$r2_nicPub_vmbusId =  '000d3a6c-e21f-000d-3a6c-e21f000d3a6c'
$r2_nicPriv_vmbusId = '000d3a6c-e516-000d-3a6c-e516000d3a6c'

$r3_nicMng_vmbusId  = '000d3af5-9754-000d-3af5-9754000d3af5'
$r3_nicPub_vmbusId  = '000d3af5-9061-000d-3af5-9061000d3af5'
$r3_nicPriv_vmbusId = '000d3af5-9d7c-000d-3af5-9d7c000d3af5'

$r1_publicNIC_DefaultGTW = '10.0.1.33'
$r1_privateNIC_DefaultGTW = '10.0.1.65'
$r2_publicNIC_DefaultGTW = '10.0.2.33'
$r2_privateNIC_DefaultGTW = '10.0.2.65'
$r3_publicNIC_DefaultGTW = '10.0.3.33'
$r3_privateNIC_DefaultGTW = '10.0.3.65'

$vnet1Name = 'vnet1'
$vnet1_MngSubnetName = 'management'
$vnet1_PubSubnetName = 'public'
$vnet1_PrivSubnetName = 'private'

$vnet2Name = 'vnet2'
$vnet2_MngSubnetName = 'management'
$vnet2_PubSubnetName = 'public'
$vnet2_PrivSubnetName = 'private'

$vnet3Name = 'vnet3'
$vnet3_MngSubnetName = 'management'
$vnet3_PubSubnetName = 'public'
$vnet3_PrivSubnetName = 'private'

$vnet1_subnet1 = '10.0.1.96/27'
$vnet2_subnet1 = '10.0.2.96/27'
$vnet3_subnet1 = '10.0.3.96/27'
$spoke1_subnet1 = '10.101.1.0/25'

$vwan_BGPPeer1 = '10.10.0.68'
$vwan_BGPPeer2 = '10.10.0.69'
####################################################
$pathFiles      = Split-Path -Parent $PSCommandPath


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
#          Write-Output $message
          Try { New-Variable -Name $key -Value $hash[$key] -ErrorAction Stop }
          Catch { Set-Variable -Name $key -Value $hash[$key] }
     }
} 
else { Write-Warning "$inputParams file not found, please change to the directory where these scripts reside ($pathFiles) and ensure this file is present."; Return }

# checking the values of variables
Write-Host "$(Get-Date) - values from file: $inputParams" -ForegroundColor Yellow
if (!$subscriptionName) { Write-Host 'variable $subscriptionName is null' ; Exit } else { Write-Host '   subscription name.....: '$subscriptionName -ForegroundColor Yellow }
if (!$resourceGroupName) { Write-Host 'variable $resourceGroupName is null' ; Exit } else { Write-Host '   resource group name...: '$resourceGroupName -ForegroundColor Yellow }
$rgName = $resourceGroupName


$subscr=Get-AzSubscription -SubscriptionName $subscriptionName
Select-AzSubscription -SubscriptionId $subscr.Id

$r1_managementNIC_PrivIP = (Get-AzNetworkInterface -Name $r1MngName -ResourceGroupName $rgName).IpConfigurations.PrivateIpAddress
$r1_publicNIC_PrivIP = (Get-AzNetworkInterface -Name $r1PubName -ResourceGroupName $rgName).IpConfigurations.PrivateIpAddress
$r1_privateNIC_PrivIP = (Get-AzNetworkInterface -Name $r1PrivName -ResourceGroupName $rgName).IpConfigurations.PrivateIpAddress
$r1_managementNIC_PublicIP = (Get-AzPublicIpAddress -Name $r1MngName -ResourceGroupName $rgName).IpAddress
$r1_publicNIC_PublicIP = (Get-AzPublicIpAddress -Name $r1PubName -ResourceGroupName $rgName).IpAddress
write-host '>>>> r1:'
write-host '  r1_NIC-management - Private IP:'$r1_managementNIC_PrivIP -ForegroundColor Yellow
write-host '  r1_NIC-public     - Private IP:'$r1_publicNIC_PrivIP  -ForegroundColor Yellow
write-host '  r1_NIC-private    - Private IP:'$r1_privateNIC_PrivIP  -ForegroundColor Yellow
write-host '  r1_NIC-management - Public  IP:'$r1_managementNIC_PublicIP  -ForegroundColor Green
write-host '  r1_NIC-public     - Public  IP:'$r1_publicNIC_PublicIP  -ForegroundColor Green
write-host '--------------------------------'


$r2_managementNIC_PrivIP = (Get-AzNetworkInterface -Name $r2MngName -ResourceGroupName $rgName).IpConfigurations.PrivateIpAddress
$r2_publicNIC_PrivIP = (Get-AzNetworkInterface -Name $r2PubName -ResourceGroupName $rgName).IpConfigurations.PrivateIpAddress
$r2_privateNIC_PrivIP = (Get-AzNetworkInterface -Name $r2PrivName -ResourceGroupName $rgName).IpConfigurations.PrivateIpAddress
$r2_managementNIC_PublicIP = (Get-AzPublicIpAddress -Name $r2MngName -ResourceGroupName $rgName).IpAddress
$r2_publicNIC_PublicIP = (Get-AzPublicIpAddress -Name $r2PubName -ResourceGroupName $rgName).IpAddress
write-host '>>>> r2:'
write-host '  r2_NIC-management - Private IP:'$r2_managementNIC_PrivIP -ForegroundColor Yellow
write-host '  r2_NIC-public     - Private IP:'$r2_publicNIC_PrivIP  -ForegroundColor Yellow
write-host '  r2_NIC-private    - Private IP:'$r2_privateNIC_PrivIP  -ForegroundColor Yellow
write-host '  r2_NIC-management - Public  IP:'$r2_managementNIC_PublicIP  -ForegroundColor Green
write-host '  r2_NIC-public     - Public  IP:'$r2_publicNIC_PublicIP  -ForegroundColor Green
write-host "--------------------------------"


$r3_managementNIC_PrivIP = (Get-AzNetworkInterface -Name $r3MngName -ResourceGroupName $rgName).IpConfigurations.PrivateIpAddress
$r3_publicNIC_PrivIP = (Get-AzNetworkInterface -Name $r3PubName -ResourceGroupName $rgName).IpConfigurations.PrivateIpAddress
$r3_privateNIC_PrivIP = (Get-AzNetworkInterface -Name $r3PrivName -ResourceGroupName $rgName).IpConfigurations.PrivateIpAddress
$r3_managementNIC_PublicIP = (Get-AzPublicIpAddress -Name $r3MngName -ResourceGroupName $rgName).IpAddress
$r3_publicNIC_PublicIP = (Get-AzPublicIpAddress -Name $r3PubName -ResourceGroupName $rgName).IpAddress
write-host '>>>> r3:'
write-host '  r3_NIC-management - Private IP:'$r3_managementNIC_PrivIP -ForegroundColor Yellow
write-host '  r3_NIC-public     - Private IP:'$r3_publicNIC_PrivIP  -ForegroundColor Yellow
write-host '  r3_NIC-private    - Private IP:'$r3_privateNIC_PrivIP  -ForegroundColor Yellow
write-host '  r3_NIC-management - Public  IP:'$r3_managementNIC_PublicIP  -ForegroundColor Green
write-host '  r3_NIC-public     - Public  IP:'$r3_publicNIC_PublicIP  -ForegroundColor Green
write-host '--------------------------------'
write-host ''

# getting the subnet mask of subnets 
$sub=(Get-AzVirtualNetworkSubnetConfig -Name $vnet1_PubSubnetName -VirtualNetwork $(Get-AzVirtualNetwork -Name $vnet1Name -ResourceGroupName $rgName)).AddressPrefix[0]
$vnet1_PublicSubnet_Mask=$sub.Substring($sub.IndexOf('/')+1)
$sub=(Get-AzVirtualNetworkSubnetConfig -Name $vnet1_PrivSubnetName -VirtualNetwork $(Get-AzVirtualNetwork -Name $vnet1Name -ResourceGroupName $rgName)).AddressPrefix[0]
$vnet1_PrivateSubnet_Mask=$sub.Substring($sub.IndexOf('/')+1)

$sub=(Get-AzVirtualNetworkSubnetConfig -Name $vnet2_PubSubnetName -VirtualNetwork $(Get-AzVirtualNetwork -Name $vnet2Name -ResourceGroupName $rgName)).AddressPrefix[0]
$vnet2_PublicSubnet_Mask=$sub.Substring($sub.IndexOf('/')+1)
$sub=(Get-AzVirtualNetworkSubnetConfig -Name $vnet2_PrivSubnetName -VirtualNetwork $(Get-AzVirtualNetwork -Name $vnet2Name -ResourceGroupName $rgName)).AddressPrefix[0]
$vnet2_PrivateSubnet_Mask=$sub.Substring($sub.IndexOf('/')+1)

$sub=(Get-AzVirtualNetworkSubnetConfig -Name $vnet3_PubSubnetName -VirtualNetwork $(Get-AzVirtualNetwork -Name $vnet3Name -ResourceGroupName $rgName)).AddressPrefix[0]
$vnet3_PublicSubnet_Mask=$sub.Substring($sub.IndexOf('/')+1)
$sub=(Get-AzVirtualNetworkSubnetConfig -Name $vnet3_PrivSubnetName -VirtualNetwork $(Get-AzVirtualNetwork -Name $vnet3Name -ResourceGroupName $rgName)).AddressPrefix[0]
$vnet3_PrivateSubnet_Mask=$sub.Substring($sub.IndexOf('/')+1)

Write-Host '[vnet1-subnet_public]  - mask: '$vnet1_PublicSubnet_Mask
Write-Host '[vnet1-subnet_private] - mask: '$vnet1_PrivateSubnet_Mask
Write-Host '[vnet2-subnet_public]  - mask: '$vnet2_PublicSubnet_Mask
Write-Host '[vnet2-subnet_private] - mask: '$vnet2_PrivateSubnet_Mask
Write-Host '[vnet3-subnet_public]  - mask: '$vnet3_PublicSubnet_Mask
Write-Host '[vnet3-subnet_private] - mask: '$vnet3_PrivateSubnet_Mask
write-host ''

#####
$fileName = "ssr-config.txt"            # filename of output txt file with SSR config


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
$SSRConfig = @"
config authority router r1 name                 r1
config authority router r1 inter-node-security  internal

config authority router r1 node r1 name              r1
config authority router r1 node r1 asset-id          r1
config authority router r1 node r1 role              combo

config authority router r1 node r1 device-interface wan name               wan
config authority router r1 node r1 device-interface wan vmbus-uuid         $r1_nicPub_vmbusId

config authority router r1 node r1 device-interface wan network-interface wan name                   wan
config authority router r1 node r1 device-interface wan network-interface wan global-id              1

config authority router r1 node r1 device-interface wan network-interface wan neighborhood internet name                  internet
config authority router r1 node r1 device-interface wan network-interface wan neighborhood internet topology              mesh
config authority router r1 node r1 device-interface wan network-interface wan neighborhood internet external-nat-address  $r1_publicNIC_PublicIP
config authority router r1 node r1 device-interface wan network-interface wan inter-router-security  internal

config authority router r1 node r1 device-interface wan network-interface wan address $r1_publicNIC_PrivIP ip-address     $r1_publicNIC_PrivIP
config authority router r1 node r1 device-interface wan network-interface wan address $r1_publicNIC_PrivIP prefix-length  $vnet1_PublicSubnet_Mask
config authority router r1 node r1 device-interface wan network-interface wan address $r1_publicNIC_PrivIP gateway        $r1_publicNIC_DefaultGTW

config authority router r1 node r1 device-interface lan name               lan
config authority router r1 node r1 device-interface lan vmbus-uuid         $r1_nicPriv_vmbusId
config authority router r1 node r1 device-interface lan capture-filter     len>0

config authority router r1 node r1 device-interface lan network-interface lan name                   lan
config authority router r1 node r1 device-interface lan network-interface lan global-id              2

config authority router r1 node r1 device-interface lan network-interface lan neighborhood vnet1-subnet1 name  vnet1-subnet1

config authority router r1 node r1 device-interface lan network-interface lan neighborhood spoke-subnet1 name  spoke-subnet1
config authority router r1 node r1 device-interface lan network-interface lan inter-router-security  internal
config authority router r1 node r1 device-interface lan network-interface lan source-nat             false

config authority router r1 node r1 device-interface lan network-interface lan address $r1_privateNIC_PrivIP ip-address     $r1_privateNIC_PrivIP
config authority router r1 node r1 device-interface lan network-interface lan address $r1_privateNIC_PrivIP prefix-length  $vnet1_PrivateSubnet_Mask
config authority router r1 node r1 device-interface lan network-interface lan address $r1_privateNIC_PrivIP gateway        $r1_privateNIC_DefaultGTW

config authority router r1 routing default-instance type              default-instance

config authority router r1 routing default-instance routing-protocol bgp type            bgp
config authority router r1 routing default-instance routing-protocol bgp local-as        65001
config authority router r1 routing default-instance routing-protocol bgp router-id       $r1_privateNIC_PrivIP

config authority router r1 routing default-instance routing-protocol bgp address-family ipv4-unicast afi-safi  ipv4-unicast

config authority router r1 routing default-instance routing-protocol bgp neighbor $vwan_BGPPeer1 neighbor-address  $vwan_BGPPeer1
config authority router r1 routing default-instance routing-protocol bgp neighbor $vwan_BGPPeer1 neighbor-as       65515


config authority router r1 routing default-instance routing-protocol bgp neighbor $vwan_BGPPeer1 transport local-address node       r1
config authority router r1 routing default-instance routing-protocol bgp neighbor $vwan_BGPPeer1 transport local-address interface  lan

config authority router r1 routing default-instance routing-protocol bgp neighbor $vwan_BGPPeer1 multihop ttl  255

config authority router r1 routing default-instance routing-protocol bgp neighbor $vwan_BGPPeer1 address-family ipv4-unicast afi-safi       ipv4-unicast
config authority router r1 routing default-instance routing-protocol bgp neighbor $vwan_BGPPeer1 address-family ipv4-unicast next-hop-self  true

config authority router r1 routing default-instance routing-protocol bgp neighbor $vwan_BGPPeer2 neighbor-address  $vwan_BGPPeer2
config authority router r1 routing default-instance routing-protocol bgp neighbor $vwan_BGPPeer2 neighbor-as       65515


config authority router r1 routing default-instance routing-protocol bgp neighbor $vwan_BGPPeer2 transport local-address node       r1
config authority router r1 routing default-instance routing-protocol bgp neighbor $vwan_BGPPeer2 transport local-address interface  lan

config authority router r1 routing default-instance routing-protocol bgp neighbor $vwan_BGPPeer2 multihop ttl  255

config authority router r1 routing default-instance routing-protocol bgp neighbor $vwan_BGPPeer2 address-family ipv4-unicast afi-safi       ipv4-unicast
config authority router r1 routing default-instance routing-protocol bgp neighbor $vwan_BGPPeer2 address-family ipv4-unicast next-hop-self  true

config authority router r1 routing default-instance routing-protocol bgp redistribute service protocol  service

config authority router r1 routing default-instance static-route $vwan_BGPPeer1/32 1 destination-prefix  $vwan_BGPPeer1/32
config authority router r1 routing default-instance static-route $vwan_BGPPeer1/32 1 distance            1
config authority router r1 routing default-instance static-route $vwan_BGPPeer1/32 1 next-hop            $r1_privateNIC_DefaultGTW

config authority router r1 routing default-instance static-route $vwan_BGPPeer1/32 1 next-hop-interface r1 lan node       r1
config authority router r1 routing default-instance static-route $vwan_BGPPeer1/32 1 next-hop-interface r1 lan interface  lan

config authority router r1 routing default-instance static-route $vwan_BGPPeer2/32 1 destination-prefix  $vwan_BGPPeer2/32
config authority router r1 routing default-instance static-route $vwan_BGPPeer2/32 1 distance            1
config authority router r1 routing default-instance static-route $vwan_BGPPeer2/32 1 next-hop            $r1_privateNIC_DefaultGTW

config authority router r1 routing default-instance static-route $vwan_BGPPeer2/32 1 next-hop-interface r1 lan node       r1
config authority router r1 routing default-instance static-route $vwan_BGPPeer2/32 1 next-hop-interface r1 lan interface  lan

config authority router r1 service-route vnet1-subnet1 name          vnet1-subnet1
config authority router r1 service-route vnet1-subnet1 service-name  vnet1-subnet1

config authority router r1 service-route vnet1-subnet1 next-hop r1 lan node-name   r1
config authority router r1 service-route vnet1-subnet1 next-hop r1 lan interface   lan
config authority router r1 service-route vnet1-subnet1 next-hop r1 lan gateway-ip  $r1_privateNIC_DefaultGTW

config authority router r1 service-route spoke1-subnet1 name                spoke1-subnet1
config authority router r1 service-route spoke1-subnet1 service-name        spoke1-subnet1
config authority router r1 service-route spoke1-subnet1 use-learned-routes

config authority router r2 name                 r2
config authority router r2 inter-node-security  internal

config authority router r2 node r2 name              r2
config authority router r2 node r2 asset-id          r2
config authority router r2 node r2 role              combo

config authority router r2 node r2 device-interface wan name               wan
config authority router r2 node r2 device-interface wan vmbus-uuid         $r2_nicPub_vmbusId

config authority router r2 node r2 device-interface wan network-interface wan name                   wan
config authority router r2 node r2 device-interface wan network-interface wan global-id              3

config authority router r2 node r2 device-interface wan network-interface wan neighborhood internet name                  internet
config authority router r2 node r2 device-interface wan network-interface wan neighborhood internet topology              mesh
config authority router r2 node r2 device-interface wan network-interface wan neighborhood internet external-nat-address  $r2_publicNIC_PublicIP
config authority router r2 node r2 device-interface wan network-interface wan inter-router-security  internal

config authority router r2 node r2 device-interface wan network-interface wan address $r2_publicNIC_PrivIP ip-address     $r2_publicNIC_PrivIP
config authority router r2 node r2 device-interface wan network-interface wan address $r2_publicNIC_PrivIP prefix-length  $vnet2_PublicSubnet_Mask
config authority router r2 node r2 device-interface wan network-interface wan address $r2_publicNIC_PrivIP gateway        $r2_publicNIC_DefaultGTW

config authority router r2 node r2 device-interface lan name               lan
config authority router r2 node r2 device-interface lan vmbus-uuid         $r2_nicPriv_vmbusId

config authority router r2 node r2 device-interface lan network-interface lan name                   lan
config authority router r2 node r2 device-interface lan network-interface lan global-id              4

config authority router r2 node r2 device-interface lan network-interface lan neighborhood vnet2-subnet1 name  vnet2-subnet1
config authority router r2 node r2 device-interface lan network-interface lan inter-router-security  internal
config authority router r2 node r2 device-interface lan network-interface lan source-nat             false

config authority router r2 node r2 device-interface lan network-interface lan address $r2_privateNIC_PrivIP ip-address     $r2_privateNIC_PrivIP
config authority router r2 node r2 device-interface lan network-interface lan address $r2_privateNIC_PrivIP prefix-length  $vnet2_PrivateSubnet_Mask
config authority router r2 node r2 device-interface lan network-interface lan address $r2_privateNIC_PrivIP gateway        $r2_privateNIC_DefaultGTW

config authority router r2 service-route vnet2-subnet1 name          vnet2-subnet1
config authority router r2 service-route vnet2-subnet1 service-name  vnet2-subnet1

config authority router r2 service-route vnet2-subnet1 next-hop r2 lan node-name   r2
config authority router r2 service-route vnet2-subnet1 next-hop r2 lan interface   lan
config authority router r2 service-route vnet2-subnet1 next-hop r2 lan gateway-ip  $r2_privateNIC_DefaultGTW

config authority router r3 name                 r3
config authority router r3 inter-node-security  internal

config authority router r3 node r3 name              r3
config authority router r3 node r3 asset-id          r3
config authority router r3 node r3 role              combo

config authority router r3 node r3 device-interface wan name               wan
config authority router r3 node r3 device-interface wan vmbus-uuid         $r3_nicPub_vmbusId

config authority router r3 node r3 device-interface wan network-interface wan name                   wan
config authority router r3 node r3 device-interface wan network-interface wan global-id              5

config authority router r3 node r3 device-interface wan network-interface wan neighborhood internet name                  internet
config authority router r3 node r3 device-interface wan network-interface wan neighborhood internet topology              mesh
config authority router r3 node r3 device-interface wan network-interface wan neighborhood internet external-nat-address  $r3_publicNIC_PublicIP
config authority router r3 node r3 device-interface wan network-interface wan inter-router-security  internal

config authority router r3 node r3 device-interface wan network-interface wan address $r3_publicNIC_PrivIP ip-address     $r3_publicNIC_PrivIP
config authority router r3 node r3 device-interface wan network-interface wan address $r3_publicNIC_PrivIP prefix-length  $vnet3_PublicSubnet_Mask
config authority router r3 node r3 device-interface wan network-interface wan address $r3_publicNIC_PrivIP gateway        $r3_publicNIC_DefaultGTW

config authority router r3 node r3 device-interface lan name               lan
config authority router r3 node r3 device-interface lan vmbus-uuid         $r3_nicPriv_vmbusId

config authority router r3 node r3 device-interface lan network-interface lan name                   lan
config authority router r3 node r3 device-interface lan network-interface lan global-id              6

config authority router r3 node r3 device-interface lan network-interface lan neighborhood vnet3-subnet1 name  vnet3-subnet1
config authority router r3 node r3 device-interface lan network-interface lan inter-router-security  internal
config authority router r3 node r3 device-interface lan network-interface lan source-nat             false

config authority router r3 node r3 device-interface lan network-interface lan address $r3_privateNIC_PrivIP ip-address     $r3_privateNIC_PrivIP
config authority router r3 node r3 device-interface lan network-interface lan address $r3_privateNIC_PrivIP prefix-length  $vnet3_PrivateSubnet_Mask
config authority router r3 node r3 device-interface lan network-interface lan address $r3_privateNIC_PrivIP gateway        $r3_privateNIC_DefaultGTW

config authority router r3 service-route vnet3-subnet1 name          vnet3-subnet1
config authority router r3 service-route vnet3-subnet1 service-name  vnet3-subnet1

config authority router r3 service-route vnet3-subnet1 next-hop r3 lan node-name   r3
config authority router r3 service-route vnet3-subnet1 next-hop r3 lan interface   lan
config authority router r3 service-route vnet3-subnet1 next-hop r3 lan gateway-ip  $r3_privateNIC_DefaultGTW

config authority router conductor name  conductor

config authority router conductor node conductor name  conductor

config authority tenant vnet1-subnet1 name    vnet1-subnet1

config authority tenant vnet1-subnet1 member vnet1-subnet1 neighborhood  vnet1-subnet1
config authority tenant vnet1-subnet1 member vnet1-subnet1 address       $vnet1_subnet1

config authority tenant vnet2-subnet1 name    vnet2-subnet1

config authority tenant vnet2-subnet1 member vnet2-subnet1 neighborhood  vnet2-subnet1
config authority tenant vnet2-subnet1 member vnet2-subnet1 address       $vnet2_subnet1

config authority tenant vnet3-subnet1 name    vnet3-subnet1

config authority tenant vnet3-subnet1 member vnet3-subnet1 neighborhood  vnet3-subnet1
config authority tenant vnet3-subnet1 member vnet3-subnet1 address       $vnet3_subnet1

config authority tenant spoke1-subnet1 name    spoke1-subnet1

config authority tenant spoke1-subnet1 member spoke-subnet1 neighborhood  spoke-subnet1
config authority tenant spoke1-subnet1 member spoke-subnet1 address       $spoke1_subnet1

config authority security internal name                 internal
config authority security internal adaptive-encryption  false

config authority service vnet1-subnet1 name           vnet1-subnet1
config authority service vnet1-subnet1 security       internal
config authority service vnet1-subnet1 address        $vnet1_subnet1

config authority service vnet1-subnet1 access-policy vnet2-subnet1 source  vnet2-subnet1

config authority service vnet1-subnet1 access-policy vnet3-subnet1 source  vnet3-subnet1

config authority service vnet1-subnet1 access-policy spoke1-subnet1 source  spoke1-subnet1

config authority service vnet2-subnet1 name           vnet2-subnet1
config authority service vnet2-subnet1 security       internal
config authority service vnet2-subnet1 address        $vnet2_subnet1

config authority service vnet2-subnet1 access-policy vnet1-subnet1 source  vnet1-subnet1

config authority service vnet2-subnet1 access-policy vnet3-subnet1 source  vnet3-subnet1

config authority service vnet2-subnet1 access-policy spoke1-subnet1 source  spoke1-subnet1

config authority service vnet3-subnet1 name           vnet3-subnet1
config authority service vnet3-subnet1 security       internal
config authority service vnet3-subnet1 address        $vnet3_subnet1

config authority service vnet3-subnet1 access-policy vnet1-subnet1 source  vnet1-subnet1

config authority service vnet3-subnet1 access-policy vnet2-subnet1 source  vnet2-subnet1

config authority service vnet3-subnet1 access-policy spoke1-subnet1 source  spoke1-subnet1

config authority service spoke1-subnet1 name           spoke1-subnet1
config authority service spoke1-subnet1 security       internal
config authority service spoke1-subnet1 address        $spoke1_subnet1

config authority service spoke1-subnet1 access-policy vnet1-subnet1 source  vnet1-subnet1

config authority service spoke1-subnet1 access-policy vnet2-subnet1 source  vnet2-subnet1

config authority service spoke1-subnet1 access-policy vnet3-subnet1 source  vnet3-subnet1

"@

#write the content of the CSR config in a file
$pathFiles = Split-Path -Parent $PSCommandPath
Set-Content -Path "$pathFiles\$fileName" -Value $SSRConfig 
