#
# Description: This script will show the properties of a multi pool gateway in Azure VPN Gateway.
# Run the script after the configuration of the multi pool gateway has been completed.
#
$rgName = 'p2s-multipool1'   
$gw1Name = 'gw1'           


$gw = get-AzVirtualNetworkGateway -Name $gw1Name -ResourceGroupName $rgName

foreach ($grp in $gw.VirtualNetworkGatewayPolicyGroups)
{
    foreach ($member in $grp.PolicyMembers)
    {
        $propertiesGroup ="name member: "+ $member.Name + ", attribute member: " + $member.AttributeType + ", attribute value: " +$member.AttributeValue
        write-host $propertiesGroup  -ForegroundColor Cyan
    }
}

write-host "--------------------------------------------------------"

$nameMember1 = $gw.VirtualNetworkGatewayPolicyGroups[0].PolicyMembers[0].Name 
$attributeValue1 = $gw.VirtualNetworkGatewayPolicyGroups[0].PolicyMembers[0].AttributeValue
$namemember2 = $gw.VirtualNetworkGatewayPolicyGroups[1].PolicyMembers[0].Name 
$attributeValue2 = $gw.VirtualNetworkGatewayPolicyGroups[1].PolicyMembers[0].AttributeValue
write-host 'name: '$nameMember1' , attribute value: '$attributeValue1 -ForegroundColor Magenta
write-host 'name: '$nameMember2' , attribute value: '$attributeValue2 -ForegroundColor Magenta 
write-host 'policy group 1: '$gw.VirtualNetworkGatewayPolicyGroups[0].Name
write-host 'policy group 2: '$gw.VirtualNetworkGatewayPolicyGroups[1].Name

$gw.VirtualNetworkGatewayPolicyGroups[0].PolicyMembers[0] | Select-Object *

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
write-host $gw.VpnClientConfiguration.ClientConnectionConfigurations[0].VpnClientAddressPool.AddressPrefixes -ForegroundColor Magenta

Write-Host "addres pool assigned to the config2:" -ForegroundColor Cyan
$gw.VpnClientConfiguration.ClientConnectionConfigurations[1].VpnClientAddressPool | Select-Object * | Format-List
write-host $gw.VpnClientConfiguration.ClientConnectionConfigurations[1].VpnClientAddressPool.AddressPrefixes -ForegroundColor Magenta