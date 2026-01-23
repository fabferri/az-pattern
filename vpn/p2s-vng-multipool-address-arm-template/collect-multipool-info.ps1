#
# Description: This script will show the properties of a multipool gateway in Azure VPN Gateway.
# Run the script after the configuration of the multi pool gateway has been completed.
#
$armTemplateParametersFile = 'init.json'
$pathFiles = Split-Path -Parent $PSCommandPath
$parametersFile = "$pathFiles\$armTemplateParametersFile"

try {
    $arrayParams = (Get-Content -Raw $parametersFile | ConvertFrom-Json)
    $subscriptionName = $arrayParams.subscriptionName
    $resourceGroupName = $arrayParams.resourceGroupName
    $location = $arrayParams.location
    $vpnGatewayName = $arrayParams.vpnGatewayName;
    Write-Host "$(Get-Date) - values from file: "$parametersFile -ForegroundColor Yellow
    if (!$subscriptionName) { Write-Host 'variable $subscriptionName is null' ; Exit }     else { Write-Host '   subscriptionName...: '$subscriptionName -ForegroundColor Yellow }
    if (!$resourceGroupName) { Write-Host 'variable $resourceGroupName is null' ; Exit }   else { Write-Host '   resourceGroupName..: '$resourceGroupName -ForegroundColor Yellow }
    if (!$location) { Write-Host 'variable $location is null' ; Exit }                     else { Write-Host '   location...........: '$location -ForegroundColor Yellow }
    if (!$vpnGatewayName) { Write-Host 'variable $vpnGatewayName is null' ; Exit }         else { Write-Host '   vpnGateway Name....: '$vpnGatewayName -ForegroundColor Green }
} 
catch {
    Write-Host 'error in reading the template file: '$parametersFile -ForegroundColor Yellow
    Exit
}           
$rgName = $resourceGroupName

$subscr = Get-AzSubscription -SubscriptionName $subscriptionName
Select-AzSubscription -SubscriptionId $subscr.Id | Format-Table


write-host "--------------------------------------------------------"
write-host 'loop to fetch the Gateway Policy Groups'
$gw = get-AzVirtualNetworkGateway -Name $vpnGatewayName -ResourceGroupName $rgName

foreach ($grp in $gw.VirtualNetworkGatewayPolicyGroups)
{
    foreach ($member in $grp.PolicyMembers)
    {
        $propertiesGroup ="name member: "+ $member.Name + ", attribute member: " + $member.AttributeType + ", attribute value: " +$member.AttributeValue
        write-host $propertiesGroup  -ForegroundColor Cyan
    }
}
write-host "--------------------------------------------------------" -ForegroundColor White

$policyGroup1Name = $gw.VirtualNetworkGatewayPolicyGroups[0].Name
$policyGroup2Name = $gw.VirtualNetworkGatewayPolicyGroups[1].Name
$nameMember1 = $gw.VirtualNetworkGatewayPolicyGroups[0].PolicyMembers[0].Name 
$attributeValue1 = $gw.VirtualNetworkGatewayPolicyGroups[0].PolicyMembers[0].AttributeValue
$namemember2 = $gw.VirtualNetworkGatewayPolicyGroups[1].PolicyMembers[0].Name 
$attributeValue2 = $gw.VirtualNetworkGatewayPolicyGroups[1].PolicyMembers[0].AttributeValue

write-host 'policy group 1: '$policyGroup1Name' , member name: '$nameMember1' , attribute value: '$attributeValue1 -ForegroundColor Cyan
write-host 'policy group 2: '$policyGroup2Name' , member name: '$nameMember2' , attribute value: '$attributeValue2 -ForegroundColor Cyan


# $gw.VirtualNetworkGatewayPolicyGroups[0].PolicyMembers[0] | Select-Object *

# show all the properties of the Gateway
#   $gw | Select-Object -Property * | Format-List

# show ip configuration
#    Write-Host "Gateway IP configuration:" -ForegroundColor Cyan
#    $gw.IpConfigurations | Select-Object -Property * | Format-List

# show all the Gateway policy groups
#   Write-Host "Gateway Policy Groups:" -ForegroundColor Cyan
#   $gw.VirtualNetworkGatewayPolicyGroups | Select-Object -Property * | Format-List


# show all the Gateway policy groups
#    Write-Host "vpn client configuration:" -ForegroundColor Cyan
#    $gw.VpnClientConfiguration | Select-Object -Property * | Format-List
write-host ""
Write-Host "vpn client Connection configurations:" -ForegroundColor Cyan
$gw.VpnClientConfiguration.ClientConnectionConfigurations | Select-Object * | Format-List
Write-Host ""
Write-Host "addres pool assigned to the config1:" -ForegroundColor Cyan
$gw.VpnClientConfiguration.ClientConnectionConfigurations[0].VpnClientAddressPool | Select-Object * | Format-List
write-host 'AddressPrefixes............: '$gw.VpnClientConfiguration.ClientConnectionConfigurations[0].VpnClientAddressPool.AddressPrefixes -ForegroundColor Magenta

Write-Host ""
Write-Host "addres pool assigned to the config2:" -ForegroundColor Cyan
$gw.VpnClientConfiguration.ClientConnectionConfigurations[1].VpnClientAddressPool | Select-Object * | Format-List
write-host 'AddressPrefixes............: '$gw.VpnClientConfiguration.ClientConnectionConfigurations[1].VpnClientAddressPool.AddressPrefixes -ForegroundColor Magenta