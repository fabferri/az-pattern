$subscriptionName = 'AzureDemo'
$rgName = 'Swap2'
$vnetName = 'vnet1'
$subnetName = 'subnet1'
$logFileName = 'logtime.txt'
$vm1Name = 'vm1'
$vm2Name = 'vm2'

$pathFiles = Split-Path -Parent $PSCommandPath
$logFile = "$pathFiles\$logFileName"

$subscr = Get-AzSubscription -SubscriptionName $subscriptionName
Select-AzSubscription -SubscriptionId $subscr.Id

Try {
    Get-AzResourceGroup -Name $rgName -ErrorAction Stop
    Write-Host "$(Get-Date) - resource group: $rgName exists. Carry on!"
}
Catch { 
    Write-Host "Resource Group: $rgName doesn't exist" -ForegroundColor Red
    Exit
}

# get the public IP address name in the resource group
$pubIPName = (Get-AzPublicIpAddress -Name * -ResourceGroupName $rgName).Name

# get location
$location = (Get-AzVirtualNetwork -ResourceGroupName $rgName).location

Function discoverVM {
    param(
        [Parameter(Mandatory = $true)] [string] $vm1Name,
        [Parameter(Mandatory = $true)] [string] $vm2Name
    )

    try {
        $vm1 = Get-AzVM -name $vm1Name -ResourceGroupName $rgName
    } catch {
        Write-Host "VM: $vm1Name doesn't exist" -ForegroundColor Red
        Exit
    }
    try {
        $vm2 = Get-AzVM -name $vm2Name -ResourceGroupName $rgName
    } catch {
        Write-Host "VM: $vm2Name doesn't exist" -ForegroundColor Red
        Exit
    }
    # get the name of primary nic
    $vm1_nicName = $vm1.NetworkProfile.NetworkInterfaces[0].Id -replace '.*/'
    $vm2_nicName = $vm2.NetworkProfile.NetworkInterfaces[0].Id -replace '.*/'
    Write-Host  $vm1_nicName -ForegroundColor Green
    Write-Host  $vm2_nicName -ForegroundColor Green
    $vm1_nic = (Get-AzNetworkInterface -Name $vm1_nicName -ResourceGroupName $rgName)
    $vm2_nic = (Get-AzNetworkInterface -Name $vm2_nicName -ResourceGroupName $rgName)

    $vm1pubIP_id = $vm1_nic.IPConfigurations.PublicIpAddress.Id
    $vm2pubIP_id = $vm2_nic.IPConfigurations.PublicIpAddress.Id

    if ( ([string]::IsNullOrEmpty($vm1pubIP_id)) -and (-not [string]::IsNullOrEmpty($vm2pubIP_id)) ) {
        $vmNameOrigin = $vm2Name
        $vmNameDestination = $vm1Name
    }
    else {
        $vmNameOrigin = $vm1Name
        $vmNameDestination = $vm2Name
    }
    return $vmNameOrigin, $vmNameDestination
}


$vmNameOrigin, $vmNameDestination = discoverVM -vm1Name $vm1Name -vm2Name $vm2Name
write-host "VM name Origin: $vmNameOrigin | VM name Destination: $vmNameDestination" -ForegroundColor DarkMagenta 



# getting the nic name of the destination VM
$vmOrigin = Get-AzVM -name $vmNameOrigin -ResourceGroupName $rgName
$nicURI_Origin = $vmOrigin.NetworkProfile.NetworkInterfaces[0].id

$position = $nicURI_Origin.lastIndexOf('/')
$nicNameOrigin = $nicURI_Origin.Substring($position + 1)
write-host "nicName Origin.....: $nicNameOrigin" -ForegroundColor Cyan


# getting the nic name of the destination VM
$vmDestination = Get-AzVM -name $vmNameDestination -ResourceGroupName $rgName
$nicURI_Destination = $vmDestination.NetworkProfile.NetworkInterfaces[0].id

$position = $nicURI_Destination.lastIndexOf('/')
$nicNameDestination = $nicURI_Destination.Substring($position + 1)
write-host "nicName Destination: $nicNameDestination" -ForegroundColor Cyan

$vmSizeOrigin = $vmOrigin.HardwareProfile.VmSize
$vmSizeDestination = $vmDestination.HardwareProfile.VmSize

# removing the public IP from the Origin VM
Write-Host "$(Get-Date) - removing public IP from the Origin VM: $vmNameOrigin" -ForegroundColor Yellow
$StartTime = Get-Date
$nicOrigin = Get-AzNetworkInterface -Name $nicNameOrigin -ResourceGroup $rgName
$nicOrigin.IpConfigurations[0].PublicIpAddress = $null
Set-AzNetworkInterface -NetworkInterface $nicOrigin

$EndTime = Get-Date
$TimeDiff = New-TimeSpan $StartTime $EndTime
$Mins = $TimeDiff.Minutes
$Secs = $TimeDiff.Seconds
$RunTime = '{0:00}:{1:00} (M:S)' -f $Mins, $Secs
Write-Host "runtime...: "$RunTime.ToString()  -ForegroundColor Yellow
write-host "start time: "$StartTime -ForegroundColor Yellow
write-host "end time..: "$EndTime -ForegroundColor Yellow

Add-Content -Path $logFile -Value '-------------------------------------'
Add-Content -Path $logFile -Value "$(Get-Date) - location: $location"
Add-Content -Path $logFile -Value "$(Get-Date) - Origin VM size: $vmSizeOrigin"
Add-Content -Path $logFile -Value "$(Get-Date) - removing public IP from the Origin VM: $vmNameOrigin"
Add-Content -Path $logFile -Value "$(Get-Date) - runtime...: $RunTime"
Add-Content -Path $logFile -Value "$(Get-Date) - start time: $StartTime"
Add-Content -Path $logFile -Value "$(Get-Date) - end time..: $EndTime"
Add-Content -Path $logFile -Value ''


# removing the public IP from the Origin VM
Write-Host "$(Get-Date) - assign public IP from the Destination VM: $vmNameDestination" -ForegroundColor Yellow
$StartTime = Get-Date
# assign the public IP from the Origin VM to destination VM
$vnet = Get-AzVirtualNetwork -Name $vnetName -ResourceGroupName $rgName
$subnet = Get-AzVirtualNetworkSubnetConfig -Name $subnetName -VirtualNetwork $vnet
$nicDestination = Get-AzNetworkInterface -Name $nicNameDestination -ResourceGroupName $rgName
$pip = Get-AzPublicIpAddress -Name $pubIPName -ResourceGroupName $rgName
$nicDestination | Set-AzNetworkInterfaceIpConfig -Name ipconfig1 -PublicIPAddress $pip -Subnet $subnet
$nicDestination | Set-AzNetworkInterface


$EndTime = Get-Date
$TimeDiff = New-TimeSpan $StartTime $EndTime
$Mins = $TimeDiff.Minutes
$Secs = $TimeDiff.Seconds
$RunTime = '{0:00}:{1:00} (M:S)' -f $Mins, $Secs
Write-Host "runtime...: "$RunTime.ToString()  -ForegroundColor Yellow
write-host "start time: "$StartTime -ForegroundColor Yellow
write-host "end time..: "$EndTime -ForegroundColor Yellow


# write to file
Add-Content -Path $logFile -Value "$(Get-Date) - location: $location"
Add-Content -Path $logFile -Value "$(Get-Date) - Origin VM size: $vmSizeDestination"
Add-Content -Path $logFile -Value "$(Get-Date) - assign public IP from the Destination VM: $vmNameDestination"
Add-Content -Path $logFile -Value "$(Get-Date) - runtime...: $RunTime"
Add-Content -Path $logFile -Value "$(Get-Date) - start time: $StartTime"
Add-Content -Path $logFile -Value "$(Get-Date) - end time..: $EndTime"
Add-Content -Path $logFile -Value '-------------------------------------'