$subscriptionName = 'AzureDemo'
$rgName = 'test-natgw'
$vnetName = 'vnet1'
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

try {
    $virtualNetwork = Get-AzVirtualNetwork -Name $vnetName -ResourceGroupName $rgName
    # get location 
    $location = (Get-AzVirtualNetwork -ResourceGroupName $rgName).location
    Write-Host "vnet: "$virtualNetwork.Name" location: "$location
}
catch {
    Write-Host "vnet: "$virtualNetwork.Name" doesn't exist" -ForegroundColor Red
    Exit
}


Function discoverVM {
    param(
        [Parameter(Mandatory = $true)] [string] $vm1Name,
        [Parameter(Mandatory = $true)] [string] $vm2Name
    )

    try {
        $vm1 = Get-AzVM -name $vm1Name -ResourceGroupName $rgName
    }
    catch {
        Write-Host "VM: $vm1Name doesn't exist" -ForegroundColor Red
        Exit
    }
    try {
        $vm2 = Get-AzVM -name $vm2Name -ResourceGroupName $rgName
    }
    catch {
        Write-Host "VM: $vm2Name doesn't exist" -ForegroundColor Red
        Exit
    }
    # get the name NIC name
    $vm1_nicName = $vm1.NetworkProfile.NetworkInterfaces[0].Id -replace '.*/'
    $vm2_nicName = $vm2.NetworkProfile.NetworkInterfaces[0].Id -replace '.*/'
    Write-Host  $vm1Name" NIC name: "$vm1_nicName -ForegroundColor Green
    Write-Host  $vm2Name" NIC name: "$vm2_nicName -ForegroundColor Green
    $vm1_nic = (Get-AzNetworkInterface -Name $vm1_nicName -ResourceGroupName $rgName)
    $vm2_nic = (Get-AzNetworkInterface -Name $vm2_nicName -ResourceGroupName $rgName)

    $vm1privIP = $vm1_nic.IPConfigurations[1].PrivateIpAddress
    $vm2privIP = $vm2_nic.IPConfigurations[1].PrivateIpAddress
    Write-Host $vm1Name" secondary private IP: "$vm1privIP -ForegroundColor Green
    Write-Host $vm2Name" secondary private IP: "$vm2privIP -ForegroundColor Green

    if ( ([string]::IsNullOrEmpty($vm1privIP)) -and ( -not [string]::IsNullOrEmpty($vm2privIP)) ) {
        # $vmNameOrigin = $vm2Name
        $vmOrigin = $vm2
        $vmNicOrigin = $vm2_nic
        # $vmNameDestination = $vm1Name
        $vmDestination = $vm1
        $vmNicDestination = $vm1_nic
    }
    elseif ( ( -not [string]::IsNullOrEmpty($vm1privIP)) -and ( [string]::IsNullOrEmpty($vm2privIP)) ) {
        # $vmNameOrigin = $vm1Name
        $vmOrigin = $vm1
        $vmNicOrigin = $vm1_nic
        # $vmNameDestination = $vm2Name
        $vmDestination = $vm2
        $vmNicDestination = $vm2_nic
    }
    else {
        write-host 'error in getting secondary private IP'
        Exit
    }
    return $vmOrigin, $vmNicOrigin, $vmDestination, $vmNicDestination
}


$vmOrigin, $vmNicOrigin, $vmDestination, $vmNicDestination = discoverVM -vm1Name $vm1Name -vm2Name $vm2Name
$vmNameOrigin = $vmOrigin.Name
$vmNameDestination = $vmDestination.Name
write-host "VM name Origin: $vmNameOrigin | VM name Destination: $vmNameDestination" -ForegroundColor DarkMagenta 

# get the VM SKU
$vmSizeOrigin = $vmOrigin.HardwareProfile.VmSize
$vmSizeDestination = $vmDestination.HardwareProfile.VmSize




$vmDestIPConfigName = $vmNicOrigin.IpConfigurations[1].Name
$vmDestPrivIP = $vmNicOrigin.IpConfigurations[1].PrivateIpAddress
$vmDestSubnetName = ($vmNicOrigin.IpConfigurations.subnet.id).Split('/')[-1]
$vmDestSubnet = Get-AzVirtualNetworkSubnetConfig -Name $vmDestSubnetName -VirtualNetwork $virtualNetwork

# removing the secondary private IP from the Origin VM
Write-Host "$(Get-Date) - removing secondary private IP from the Origin VM: $vmNameOrigin" -ForegroundColor Yellow
$StartTime = Get-Date

## Delete secondary private IP in the Origin VM ##
Remove-AzNetworkInterfaceIpConfig -Name $vmNicOrigin.IpConfigurations[1].Name -NetworkInterface $vmNicOrigin
## Update the network interface with new changes. ##
Set-AzNetworkInterface -NetworkInterface $vmNicOrigin

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



# assign the the secondary private IP to the Destination VM
Write-Host "$(Get-Date) - assign private IP: $vmDestPrivIP to the Destination VM: $vmNameDestination" -ForegroundColor Yellow
$StartTime = Get-Date

Add-AzNetworkInterfaceIpConfig -Name $vmDestIPConfigName -NetworkInterface $vmNicDestination  -PrivateIpAddress $vmDestPrivIP -Subnet $vmDestSubnet

## Update the network interface with new changes. ##
Set-AzNetworkInterface -NetworkInterface $vmNicDestination

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
Add-Content -Path $logFile -Value "$(Get-Date) - assign secondary private IP: $vmDestPrivIP to the Destination VM: $vmNameDestination"
Add-Content -Path $logFile -Value "$(Get-Date) - runtime...: $RunTime"
Add-Content -Path $logFile -Value "$(Get-Date) - start time: $StartTime"
Add-Content -Path $logFile -Value "$(Get-Date) - end time..: $EndTime"
Add-Content -Path $logFile -Value '-------------------------------------'

