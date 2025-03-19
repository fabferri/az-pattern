### powershell script to create multiple policy groups for Azure VPN Gateway
### The script creates a resource group, virtual network, VPN Gateway, and multiple policy groups for the VPN Gateway
### The script uses the Az module to create the resources
### The script uses 
###   New-AzVpnClientRootCertificate cmdlet to create the root certificate for the VPN Gateway
###   New-AzVirtualNetworkGatewayPolicyGroup cmdlet to create the policy groups
###   New-AzVpnClientConnectionConfiguration cmdlet to create the client connection configurations
###   Set-AzVirtualNetworkGateway cmdlet to set the policy groups and client connection configurations on the VPN Gateway
###   Get-AzVirtualNetworkGateway cmdlet to get the VPN Gateway
###
$subscriptionName = 'Hybrid-PM-Repro-1'
$rgName = 'p2s-multipool1' 
$location = 'westus2'     
$vnet1Name = 'vnet1'
$app1SubnetName = 'appsubnet'    
$vnet1Prefix = '10.0.0.0/24'          
$app1SubnetPrefix = '10.0.0.0/26'
$gw1SubnetPrefix = '10.0.0.192/26'     
$gw1Name = 'gw1'                                 
$vpnSku = 'VpnGw2AZ'                 
$gw1IP1Name = $gw1Name + '-pubIP1'
$clientRootCertName = 'P2SRoot1.cer'
$samplePublicCertData = 'MIIC5zCCAc+gAwIBAgIQH0n3xp1vV7FBfqhwRvJOljANBgkqhkiG9w0BAQsFADAW
MRQwEgYDVQQDDAtQMlNSb290Q2VydDAeFw0yNTAzMTIxMTA3NDRaFw0yNzAzMTIx
MTE3NDNaMBYxFDASBgNVBAMMC1AyU1Jvb3RDZXJ0MIIBIjANBgkqhkiG9w0BAQEF
AAOCAQ8AMIIBCgKCAQEAsgrKJj7gM4KmdO/FmbnqNS3ukY/0yhk3ywLKOu9d9gQ6
E4xyFchCoK0w7h7pT7TjBYgfZSoWRwuFqiG3NO/wcj3RGMNMFkEq/y7fJ1YnE5PO
ntUGYY4wiqkNL9XZW7sETBo4wrd6sQmMGZOy9c83esjQ+o9H+qooHLzwrQzZVJ2C
vTfOAbiULpDU9zOlvpGhG7yfEWAtQRXi3FMcQVN21chezw2LEj9boq1u7Onb1fa8
11G7KNrmn4NJ9Zeb9vwVDJkfnvggSgnQseOKFydyhBKiJkZYcS9jY9mgW2lcZcoB
WztAbTqIlPuqO8FvTKjxHBBmAKy9OpIKmAESnvrxDQIDAQABozEwLzAOBgNVHQ8B
Af8EBAMCAgQwHQYDVR0OBBYEFKEFOBFzzIujVRfBCEKu6VJNLx0vMA0GCSqGSIb3
DQEBCwUAA4IBAQBdfFK+2Hu8ReP6MMc+iyLqzB+zm8uTdxJGtAmPZHH/X/GeOwN1
gzG3Pg2lUrlfKdBcaKte7GNWnUldmwrIlGRUB1uQshBgArdyiBJK9aCiH+b3gfIH
E1oUEdWXQGU9ZW8AN32fyBT1Wzkc1t+HeqlogAESlXpvkMEqNFVRKT2bPMz/+smp
JGkx8eKZdSpD0p98loSeiw1eSqrIaENQfZqHVpdc0QfjMCr0swD1+wzFuo55irqU
/+t28RT6NLvJDPujYU+nzgOWJfSOGWfa2y8781Lha7ccJsoC4F/0jARAlubw2rCQ
lfsYM7IjR5DoTqw2dwfdyN0MlWNytqUFxnJW'

# selection of the Azure subscription
$subscr = Get-AzSubscription -SubscriptionName $subscriptionName
Select-AzSubscription -SubscriptionId $subscr.Id

# login Check
Try {
     Write-Host 'Using Subscription: ' -NoNewline
     Write-Host $((Get-AzContext).Name) -ForegroundColor Green
}
Catch {
     Write-Warning 'You are not logged in. Login and try again!'
     Return
}

$startTime = Get-Date

# Create a resource group
Try {
     Write-Host "$(Get-Date) - creating Resource Group: $rgName" -ForegroundColor Cyan
     $rg = Get-AzResourceGroup -Name $rgName -ErrorAction Stop
     Write-Host "$(Get-Date) - resource group: $rgName exists, skipping" 
}
Catch { $rg = New-AzResourceGroup -Name $rgName -Location "$location" }


# Create Virtual Network
Try {
     Write-Host "$(Get-Date) - Creating Virtual Network: $vnet1Name" -ForegroundColor Cyan
     $vnet1 = Get-AzVirtualNetwork -ResourceGroupName $rgName -Name $vnet1Name -ErrorAction Stop
     Write-Host '  resource exists, skipping'
}
Catch {
     $vnet1 = New-AzVirtualNetwork -ResourceGroupName $rgName -Name $vnet1Name -AddressPrefix $vnet1Prefix -Location $location
     Write-Host "$(Get-Date) - Created vnet:"$vnet1.Name
} 
try {
     $app1Subnet = Get-AzVirtualNetworkSubnetConfig -Name $app1SubnetName -VirtualNetwork $vnet1 -ErrorAction Stop
     $gtw1Subnet = Get-AzVirtualNetworkSubnetConfig -Name 'GatewaySubnet' -VirtualNetwork $vnet1  -ErrorAction Stop
}
catch {
     # Add Subnets
     Write-Host "$(Get-Date) - Adding subnets: $app1SubnetName , GatewaySubnet" -ForegroundColor Cyan
     Add-AzVirtualNetworkSubnetConfig -Name $app1SubnetName -VirtualNetwork $vnet1 -AddressPrefix $app1SubnetPrefix | Out-Null
     Add-AzVirtualNetworkSubnetConfig -Name 'GatewaySubnet' -VirtualNetwork $vnet1 -AddressPrefix $gw1SubnetPrefix | Out-Null
     Set-AzVirtualNetwork -VirtualNetwork $vnet1 | Out-Null
}

Try {
     Write-Host "$(Get-Date) - creating VPN Gateway1-public IP: $gw1IP1Name" -ForegroundColor Cyan
     $gw1IP1 = Get-AzPublicIpAddress -Name $gw1IP1Name -ResourceGroupName $rgName  -ErrorAction Stop 
     Write-Host "$(Get-Date) - VPN Gateway1-Public IP:  $gw1IP1Name  exists, skipping"
}
Catch {
     # create the public IP1 for the gw1
     $gw1IP1 = New-AzPublicIpAddress -Name $gw1IP1Name `
          -ResourceGroupName $rgName `
          -Location $location `
          -AllocationMethod Static `
          -Sku Standard -Tier Regional -Zone 1, 2, 3 -IpAddressVersion IPv4  
     Write-Host "$(Get-Date) - VPN Gateway1-Public IP: $gw1IP1Name created" -ForegroundColor Green
}

# Create the gateway IP address configuration
$vnet1 = Get-AzVirtualNetwork -Name $vnet1Name -ResourceGroupName $rgName
$gw1subnet = Get-AzVirtualNetworkSubnetConfig -Name 'GatewaySubnet' -VirtualNetwork $vnet1
$gw1ipconf1 = New-AzVirtualNetworkGatewayIpConfig -Name gw1ipconfig1 -SubnetId $gw1subnet.Id -PublicIpAddressId $gw1IP1.Id


Try {
     $gw1 = Get-AzVirtualNetworkGateway -Name $gw1Name -ResourceGroupName $rgName -ErrorAction Stop
     Write-Host "$(Get-Date) - VirtualNetworkGateway: $gw1Name  exists, skipping"
}
catch {
     Write-Host "$(Get-Date) - Start creation new VirtualNetworkGateway: $gw1Name (it takes ~ 30 minutes)" -ForegroundColor Cyan
     $gw1 = New-AzVirtualNetworkGateway -Name $gw1Name -ResourceGroupName $rgName -Location $location -GatewayType Vpn -IpConfigurations $gw1ipconf1 -VpnType RouteBased -GatewaySku $vpnSku -EnableBgp $false -VpnGatewayGeneration Generation2
} 
write-host ""
write-host "$(Get-Date) - Azure VPN Gateway created successfully" -ForegroundColor Green

# Obtain the Azure VPN public IP addresses
$gw1publicIP1 = (Get-AzPublicIpAddress -Name $gw1IP1Name -ResourceGroupName $rgName).IPAddress
write-host 'Azure VPN Gateway public IP1 .:'$gw1publicIP1 -ForegroundColor Cyan

write-host "$(Get-Date) - preparing public part of the root certificate" -ForegroundColor Cyan
$rootCert = New-AzVpnClientRootCertificate -Name $clientRootCertName -PublicCertData $samplePublicCertData

write-host "$(Get-Date) - adding P2S configuration to the VPN Gateway" -ForegroundColor Cyan
$gw = Set-AzVirtualNetworkGateway -VirtualNetworkGateway $gw1 -VpnAuthenticationType Certificate -VpnClientAddressPool 192.168.0.0/24 -VpnClientRootCertificates $rootCert -VpnClientProtocol IkeV2, OpenVPN
 

write-host "$(Get-Date) - Creating two members for the gateway policy groups" -ForegroundColor Green
$member1 = New-AzVirtualNetworkGatewayPolicyGroupMember -Name "member1" -AttributeType "CertificateGroupId" -AttributeValue "engineering.contoso.com"
$member2 = New-AzVirtualNetworkGatewayPolicyGroupMember -Name "member2" -AttributeType "CertificateGroupId" -AttributeValue "sale.contoso.com"

Try {
     if (($gw.VirtualNetworkGatewayPolicyGroups[0].Name -ne 'policyGroup1') -or ($gw.VirtualNetworkGatewayPolicyGroups[1].Name -ne 'policyGroup2')) {
          # Create a Virtual Network Gateway Policy Group
          # Virtual Network Gateway Policy Group is a used for setting up different groups of users based on their identity or authentication credentials
          write-host "$(Get-Date) - Creating two gateway Policy Groups" -ForegroundColor Cyan
          $policyGroup1 = New-AzVirtualNetworkGatewayPolicyGroup -Name "policyGroup1" -Priority 0 -DefaultPolicyGroup  -PolicyMember $member1 -ErrorAction Stop 
          $policyGroup2 = New-AzVirtualNetworkGatewayPolicyGroup -Name "policyGroup2" -Priority 10 -PolicyMember $member2 -ErrorAction Stop 
          $vngconnectionConfig = New-AzVpnClientConnectionConfiguration -Name "config1" -VirtualNetworkGatewayPolicyGroup $policyGroup1 -VpnClientAddressPool "192.168.1.0/24" -ErrorAction Stop 
          $vngconnectionConfig2 = New-AzVpnClientConnectionConfiguration -Name "config2" -VirtualNetworkGatewayPolicyGroup $policyGroup2 -VpnClientAddressPool "192.168.2.0/24" -ErrorAction Stop 
          $gw = Set-AzVirtualNetworkGateway -VirtualNetworkGateway $gw1 -VirtualNetworkGatewayPolicyGroup $policyGroup1, $policyGroup2 -ClientConnectionConfiguration $vngconnectionConfig, $vngconnectionConfig2 -ErrorAction Stop 
     }
}
catch {
     write-host "$(Get-Date) - No policy groups found, creating new policy groups" -ForegroundColor Red -BackgroundColor White
     # Create a Virtual Network Gateway Policy Group
     # Virtual Network Gateway Policy Group is a used for setting up different groups of users based on their identity or authentication credentials
     write-host "$(Get-Date) - Creating two gateway Policy Groups" -ForegroundColor Cyan
     $policyGroup1 = New-AzVirtualNetworkGatewayPolicyGroup -Name "policyGroup1" -Priority 0 -DefaultPolicyGroup  -PolicyMember $member1
     $policyGroup2 = New-AzVirtualNetworkGatewayPolicyGroup -Name "policyGroup2" -Priority 10 -PolicyMember $member2
     $vngconnectionConfig = New-AzVpnClientConnectionConfiguration -Name "config1" -VirtualNetworkGatewayPolicyGroup $policyGroup1 -VpnClientAddressPool "192.168.1.0/24" 
     $vngconnectionConfig2 = New-AzVpnClientConnectionConfiguration -Name "config2" -VirtualNetworkGatewayPolicyGroup $policyGroup2 -VpnClientAddressPool "192.168.2.0/24" 
     $gw = Set-AzVirtualNetworkGateway -VirtualNetworkGateway $gw1 -VirtualNetworkGatewayPolicyGroup $policyGroup1, $policyGroup2 -ClientConnectionConfiguration $vngconnectionConfig, $vngconnectionConfig2
}

$nameMember1 = $gw.VirtualNetworkGatewayPolicyGroups[0].PolicyMembers[0].Name 
$attributeValue1 = $gw.VirtualNetworkGatewayPolicyGroups[0].PolicyMembers[0].AttributeValue
$namemember2 = $gw.VirtualNetworkGatewayPolicyGroups[1].PolicyMembers[0].Name 
$attributeValue2 = $gw.VirtualNetworkGatewayPolicyGroups[1].PolicyMembers[0].AttributeValue
write-host 'name: '$nameMember1' , attribute value: '$attributeValue1 -ForegroundColor Magenta
write-host 'name: '$nameMember2' , attribute value: '$attributeValue2 -ForegroundColor Magenta 
write-host 'policy group 1: '$gw.VirtualNetworkGatewayPolicyGroups[0].Name
write-host 'policy group 2: '$gw.VirtualNetworkGatewayPolicyGroups[1].Name

# show all the properties of the Gateway
$gw | Select-Object -Property * | Format-List

# show ip configuration
Write-Host "Gateway IP configuration:" -ForegroundColor Cyan
$gw.IpConfigurations | Select-Object -Property * | Format-List

# show all the Gateway policy groups
Write-Host "Gateway Policy Groups:" -ForegroundColor Cyan
$gw.VirtualNetworkGatewayPolicyGroups | Select-Object -Property * | Format-List

# show all the Gateway policy groups
Write-Host "vpn client configuration:" -ForegroundColor Cyan
$gw.VpnClientConfiguration | Select-Object -Property * | Format-List


$gw.VpnClientConfiguration.ClientConnectionConfigurations | Select-Object * | Format-List
Write-Host "addres pool assigned to the config1:" -ForegroundColor Cyan
$gw.VpnClientConfiguration.ClientConnectionConfigurations[0].VpnClientAddressPool | Select-Object * | Format-List
$gw.VpnClientConfiguration.ClientConnectionConfigurations[0].VpnClientAddressPool.AddressPrefixes

Write-Host "addres pool assigned to the config2:" -ForegroundColor Cyan
$gw.VpnClientConfiguration.ClientConnectionConfigurations[1].VpnClientAddressPool | Select-Object * | Format-List
$gw.VpnClientConfiguration.ClientConnectionConfigurations[1].VpnClientAddressPool.AddressPrefixes

$endTime = Get-Date
$timeDiff = New-TimeSpan $startTime $endTime
$mins = $timeDiff.Minutes
$secs = $timeDiff.Seconds
$runTime = '{0:00}:{1:00} (M:S)' -f $mins, $secs
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Script completed" -ForegroundColor Green
Write-Host "  Time to complete: $runTime"