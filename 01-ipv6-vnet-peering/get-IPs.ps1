# Getting all the IPs of the VMs
#
$subscriptionName = "AzureDemo3"
$rgName = "ipv6-1"


$vmArray = @("h11", "h11", "h2", "nva", "s1", "s2")
foreach ($vmName in $vmarray) {
    $VM = Get-AzVM -ResourceGroupName $rgName  -Name $vmName
    $NIC = $VM.NetworkProfile.NetworkInterfaces[0].Id -replace '.*\/'
    $NI = Get-AzNetworkInterface -Name $NIC -ResourceGroupName $rgName
    $NIIC = Get-AzNetworkInterfaceIpConfig -NetworkInterface $NI

    write-host "----------------------"
    foreach ($a in $NIIC) {

        write-host -ForegroundColor Cyan "$vmName-private IP address: " $a.PrivateIpAddress 
    }

    try {
        $namePubv4 = $vmName + "-pubIP"
        $namePubv6 = $vmName + "-pubIP6"
        $vm_pubv4 = (Get-AzPublicIpAddress -Name $namePubv4 -ResourceGroupName $rgName -ErrorAction Ignore).IpAddress 
        $vm_pubv6 = (Get-AzPublicIpAddress -Name $namePubv6 -ResourceGroupName $rgName -ErrorAction Ignore).IpAddress
        write-host "$vmName-public IPv4       : "$vm_pubv4 -ForegroundColor Yellow 
        write-host "$vmName-public IPv6       : "$vm_pubv6 -ForegroundColor Yellow
    }
    catch {
        write-host "$vmName-public IPv6       : -"
    } 
}