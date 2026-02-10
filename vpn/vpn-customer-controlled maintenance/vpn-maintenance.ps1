$rgName='s2s-mi'
$location='italynorth'
$maintenanceName='s2s-mi-maintenance'
$timeZone='Central European Standard Time'
$startTime='2026-02-11 02:00'
$duration='05:00'
$configAssignmentName='s2s-mi-maintenanceassignment'
$gwName='gw1'

#### one time setup to register the maintenance resource provider in your subscription:
# Register-AzResourceProvider -ProviderNamespace Microsoft.Maintenance
#
### Check that registration is completed before running the rest of the script:
# Get-AzResourceProvider -ProviderNamespace Microsoft.Maintenance

New-AzMaintenanceConfiguration -ResourceGroupName $rgName -Name $maintenanceName `
    -Location $location -MaintenanceScope Resource `
    -ExtensionProperty @{"maintenanceSubScope"="NetworkGatewayMaintenance"} `
    -StartDateTime $startTime -TimeZone $timeZone `
    -Duration $duration -Visibility "Custom" `
    -RecurEvery "1Day"

$serviceResourceId = (Get-AzVirtualNetworkGateway -ResourceGroupName $rgName -Name $gwName).Id
$maintenanceConfigId=(Get-AzMaintenanceConfiguration -ResourceGroupName $rgName -Name $maintenanceName).Id
New-AzConfigurationAssignment -ResourceGroupName $rgName -Location $location `
     -ResourceName $gwName `
     -ProviderName "Microsoft.Network" `
     -ResourceType "virtualNetworkGateways" `
     -ConfigurationAssignmentName $configAssignmentName `
     -ResourceId $serviceResourceId `
     -MaintenanceConfigurationId $maintenanceConfigId


Get-AzConfigurationAssignment -ResourceGroupName $rgName -ProviderName "Microsoft.Network" -ResourceType "virtualNetworkGateways" -ResourceName $gwName

# delete the configuration assignment when maintenance is no longer needed
Remove-AzConfigurationAssignment -ResourceGroupName $rgName -ProviderName "Microsoft.Network" -ResourceType "virtualNetworkGateways" -ResourceName $gwName -ConfigurationAssignmentName $configAssignmentName
Remove-AzMaintenanceConfiguration -ResourceGroupName $rgName -Name $maintenanceName