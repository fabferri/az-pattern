# powershell script to modifing (extend of shrink) an existing network prefix in the address space of the vnet.
#
# Description of variables:
# $rgName: name of the resource group
# $vnetName1: first vnet. it is the target vnet name we want to add the new network prefix
# $vnetName2: second vnet. it is a vnet name in peering with first vnet
# $NewNetworkPrefix: new network prefix to add to the vnet1
# $vnetPeeringName1: name of the vnet peering vnet1 to vnet2
# $vnetPeeringName2: name of the vnet peering vnet2 to vnet1

$rgName = "rg-prod"
$vnetName1 = "vnet1"
$vnetName2 = "vnet2"
$existingNetworkPrefix = "10.101.0.0/24"
$newNetworkPrefix = "10.101.0.0/23"
$vnetPeeringName1 = "vnet1Tovnet2"
$vnetPeeringName2 = "vnet2Tovnet1"

$startTime = Get-Date
# get the resource group
Try {$rg = Get-AzResourceGroup -Name $rgName -ErrorAction Stop
    Write-Host '  resource exists, skipping'}
Catch {Write-Host "Resource group: $rg doesn't exist"; Exit}

Write-Host "$(Get-Date) - getting Azure vnet: $vnetName2"
Try {$VNet = Get-AzVirtualNetwork -ResourceGroupName $rgName -Name $vnetName1 -ErrorAction Stop}
Catch { Write-Host "$(Get-Date) - vnet: $vnetName1 doesn't exist" -ForegroundColor Yellow; Exit}

Write-Host "$(Get-Date) - checking if the address prefix: $NewNetworkPrefix  exists" -ForegroundColor Cyan
Try { 
        if( $VNet.AddressSpace.AddressPrefixes.Contains($existingNetworkPrefix) ) { 
            Write-Host "$(Get-Date) - address prefix: $existingNetworkPrefix , found in the vnet: $vnetName1" -ForegroundColor Green
            $i = $VNet.AddressSpace.AddressPrefixes.IndexOf($existingNetworkPrefix)
        }
        else { Write-Host "$(Get-Date) - address prefix: $existingNetworkPrefix does not exist in vnet: $vnetName1" -ForegroundColor Yellow; Exit}
    }
Catch {Write-Host "$(Get-Date) - issue to check the address space $existingNetworkPrefix in the vnet: $vnetName1"; Exit}


Write-Host "$(Get-Date) - getting vnet peering: $vnetPeeringName2 in vnet:$vnetName2" -ForegroundColor Cyan
Try {$vnetPeering2=Get-AzVirtualNetworkPeering -Name $vnetPeeringName2 -VirtualNetworkName $vnetName2 -ResourceGroupName $rgName}
Catch {
    Write-Host "$(Get-Date) - issue to get the vnet peering: $vnetPeeringName2"; Exit
}


Try { 
    Write-Host "$(Get-Date) - vnet: $vnetName1 - change the existing network prefix $existingNetworkPrefix into $newNetworkPrefix" -ForegroundColor Cyan
    $i=$VNet.AddressSpace.AddressPrefixes.IndexOf($existingNetworkPrefix)
    # change the address space in the vnet
    $VNet.AddressSpace.AddressPrefixes.Item($i)=$newNetworkPrefix
    Set-AzVirtualNetwork -VirtualNetwork $VNet
}
Catch {Write-Host "$(Get-Date) - issue in the vnet: $vnetName1 to change the existing network prefix $existingNetworkPrefix into $newNetworkPrefix"; Exit}


Write-Host "$(Get-Date) - syncronization in the vnet: $vnetName2, vnet peering name: $vnetPeeringName2" -ForegroundColor Cyan
Sync-AzVirtualNetworkPeering -VirtualNetworkPeering $vnetPeering2

Write-Host "$(Get-Date) - vnet peering name: $vnetPeeringName2, provisioning state:"$vnetPeering2.ProvisioningState -ForegroundColor Cyan

$endTime = Get-Date
$TimeDiff = New-TimeSpan $startTime $endTime
$Mins = $TimeDiff.Minutes
$Secs = $TimeDiff.Seconds
$runTime = '{0:00}:{1:00} (M:S)' -f $Mins, $Secs
Write-Host "runtime: $runTime" -ForegroundColor Yellow