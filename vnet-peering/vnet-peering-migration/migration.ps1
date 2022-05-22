# 
#   The script aims to migrate the vnet peering in a spoke vnet. 
#   A spoke vnet is connected through vnet peering to an origin hub vnet.
#   The script creates a new peering with a new hub vnet and then delete the peering with the origin hub
#   spoke vnet, origin hub vnet and destination hub vnet are all in different resource groups.
#   All the resource groups are in the same Azure subscription.  
# 
#
# The script has the following workflow:
#  - fetch the existing vnets (origin hub vnet, spoke vnet, destination hub vnet) 
#  - fetch the existing vnet peering (peering origin hub-to-origin spoke, origin spoke-to-origin hub)
#  - check that destination hub vnet contains a gateway subnet
#  - creation of new peering from the target hub vnet to the spoke vnet
#  - creation of new peering from the spoke vnet to the targe hub vnet
#  - delete the peering from the original hub vnet to the spoke vnet
#  - delete the peering from the spoke vnet to the original hub vnet
#  - enable ALLOW GATEWAY TRANSIT attribute in the peering from the destination hub to the spoke vnet
#  - enable USE REMOTE GATEWAY attribute in the peering from the spoke vnet to the destination hub vnet
#
#
# Before running the script, check the right assigment of input variables:
#
#   $fileName : name of the log file. The script runtime value is written in the log file
#   $rgNamespokeName : name of the resource group where is deployed the spoke vnet
#   $spokevnetName : name of the spoke vnet
#   $origin_rgNamehubName : name of the resource group in origin vnet 
#   $origin_hubvnetName : name of the origin vnet
#   $destination_rgNamehubName : name of the resource group of target hub vnet
#   $destination_hubvnetName : name of the target hub vnet
#
#   $origin_spokevnetPeeringName : name of the peering from the spoke vnet to the orgin hub vnet
#   $origin_hubvnetPeeringName :  name of the peering from the origin vnet to the spoke vnet 
#   $destination_spokevnetPeeringName : name of the peering from the spoke vnet to the destination hub vnet
#   $destination_hubvnetPeeringName : name of the peering from the destination hub vnet to the spoke vnet
#
############# input variables ###########################
$header = (get-date -Format "yyyy-MM-dd-HH_mm").ToString()
$fileName = "$header-runtime-migration.txt"

$rgNamespokeName = 'SEA-Cust41'
$spokevnetName = 'SEA-Cust41-VNet02'

$origin_rgNamehubName = 'SEA-Cust41'
$origin_hubvnetName = 'SEA-Cust41-VNet01'
$destination_rgNamehubName = 'ASH-Cust30'
$destination_hubvnetName = 'ASH-Cust30-VNet01'

$origin_spokevnetPeeringName = $spokevnetName + '-to-' + $origin_hubvnetName
$origin_hubvnetPeeringName = $origin_hubvnetName + '-to-' + $spokevnetName

$destination_spokevnetPeeringName = $spokevnetName + '-to-' + $destination_hubvnetName
$destination_hubvnetPeeringName = $destination_hubvnetName + '-to-' + $spokevnetName
##########################################################

$pathFiles = Split-Path -Parent $PSCommandPath
$fileFullPathName = "$pathFiles\$fileName"

###### Checking existing vnets and vnet peering
######
try {
    $date_ = Get-Date
    # get origin hub vnet
    $origin_hubvnet = get-AzVirtualNetwork -Name $origin_hubvnetName -ResourceGroupName $origin_rgNamehubName 
    $origin_hubvnetAddressSpace = $origin_hubvnet.AddressSpace.AddressPrefixesText
    Write-Host "$date_ - getting origin hub vnet: $origin_hubvnetName , $origin_hubvnetAddressSpace" -ForegroundColor Green
    Add-Content $fileFullPathName "$date_ - getting origin hub vnet name: $origin_hubvnetName"
    Add-Content $fileFullPathName "$date_ - getting origin hub vnet address: $origin_hubvnetAddressSpace"
}
catch {
    write-host "$date_ - origin hub vnet $origin_hubvnetName does not exist!" -ForegroundColor Red
    write-host "$date_ - Exit" -ForegroundColor Red
    Add-Content $fileFullPathName "$date_ - origin hub vnet name: $origin_hubvnetName does not exist!"
    Add-Content $fileFullPathName "$date_ - Exit"
    Exit
}

try {
    $date_ = Get-Date
    # get destination hub vnet
    $destination_hubvnet = get-AzVirtualNetwork -Name $destination_hubvnetName -ResourceGroupName $destination_rgNamehubName 
    $destination_hubvnetAddressSpace = $destination_hubvnet.AddressSpace.AddressPrefixesText
    Write-Host "$date_ - getting destination hub vnet: $destination_hubvnetName , $destination_hubvnetAddressSpace" -ForegroundColor Green
    Add-Content $fileFullPathName "$date_ - getting destination hub vnet: $destination_hubvnetName , $destination_hubvnetAddressSpace"
    
}
catch {
    $date_ = Get-Date
    write-host "$date_ - destination hub vnet $destination_hubvnetName does not exist!" -ForegroundColor Red
    write-host "$date_ - Exit" -ForegroundColor Red
    Add-Content $fileFullPathName "$date_ - destination hub vnet name: $destination_hubvnetName does not exist!"
    Add-Content $fileFullPathName "$date_ - Exit"
    Exit
}

try {
    $date_ = Get-Date
    # get spoke vnet
    $spokevnet = get-AzVirtualNetwork -Name $spokevnetName -ResourceGroupName $rgNamespokeName 
    $spokevnetAddressSpace = $spokevnet.AddressSpace.AddressPrefixesText
    Write-Host "$date_ - getting destination spoke vnet: $spokevnetName , $spokevnetAddressSpace" -ForegroundColor Green
    Add-Content $fileFullPathName "$date_ - getting spoke vnet name: $spokevnetName"
    Add-Content $fileFullPathName "$date_ - getting spoke vnet address: $spokevnetAddressSpace"
}
catch {
    $date_ = Get-Date
    write-host "$date_ - spoke net $spokevnetName does not exist!" -ForegroundColor Red
    write-host "$date_ - Exit" -ForegroundColor Red
    Add-Content $fileFullPathName "$date_ - spoke net name: $spokevnetName does not exist!"
    Add-Content $fileFullPathName "$date_ - Exit"
    Exit
}

try {
    $date_ = Get-Date
    # get origin hub peering
    $origin_hubvnetPeering = Get-AzVirtualNetworkPeering -Name $origin_hubVNetPeeringName -VirtualNetwork $origin_hubVNetName -ResourceGroupName $origin_rgNamehubName
    $origin_peeringName = $origin_hubvnetPeering.Name
    $origin_vnetName = $origin_hubvnetPeering.VirtualNetworkName
    Write-Host "$date_ - getting origin hub peering: $origin_peeringName , $origin_vnetName" -ForegroundColor Green
    Add-Content $fileFullPathName "$date_ - getting origin hub peering name: $origin_peeringName"
    Add-Content $fileFullPathName "$date_ - getting origin hub vnet name: $origin_vnetName"
}
catch {
    write-host "origin hub vnet peering $origin_hubVNetPeeringName does not exist!" -ForegroundColor Red
    Add-Content $fileFullPathName "$date_ - origin hub vnet peering $origin_hubVNetPeeringName does not exist!"
    Add-Content $fileFullPathName "$date_ - Exit"
    Exit
}

try {
    $date_ = Get-Date
    # get origin spoke peering
    $origin_spokevnetPeering = Get-AzVirtualNetworkPeering -Name $origin_spokeVNetPeeringName -VirtualNetwork $spokevnetName -ResourceGroupName $rgNamespokeName
    Write-Host "$date_ - getting origin spoke peering: $origin_spokevnetPeeringName , $spokevnetName" -ForegroundColor Green
    Add-Content $fileFullPathName "$date_ - getting origin spoke peering name: $origin_peeringName"
    Add-Content $fileFullPathName "$date_ - getting spoke vnet name: $spokevnetName"
}
catch {
    $date_ = Get-Date
    write-host "$date_ - origin spoke vnet peering $origin_spokevnetPeeringName does not exist!" -ForegroundColor Red
    write-host "$date_ - Exit" -ForegroundColor Red
    Add-Content $fileFullPathName "$date_ - origin spoke vnet peering name: $origin_spokevnetPeeringName does not exist!"
    Add-Content $fileFullPathName "$date_ - Exit"
    Exit
}


if ($null -eq $origin_hubvnetPeering) {
    $date_ = Get-Date
    write-host "origin hub vnet peering  $origin_hubVNetPeeringName NOT FOUND!" -ForegroundColor Red
    write-host "Exit" -ForegroundColor Red
    Add-Content $fileFullPathName "$date_ - origin hub vnet peering name: $origin_hubVNetPeeringName NOT FOUND!"
    Add-Content $fileFullPathName "$date_ - Exit"
    Exit 
}
if ($null -eq $origin_spokevnetPeering) {
    $date_ = Get-Date
    $peeringName = $origin_spokevnetPeeringName
    write-host "$date_ - origin spoke vnet peering $origin_spokevnetPeeringName NOT FOUND!" -ForegroundColor Red
    write-host "$date_ - Exit" -ForegroundColor Red
    Add-Content $fileFullPathName "$date_ - check the correct origin spoke vnet peering name:  $origin_spokevnetPeeringName NOT FOUND!"
    Add-Content $fileFullPathName "$date_ - Exit"
    Exit 
}


####
#### at this point all the information about vnets and peering have been acquired
$date_ = Get-Date
Add-Content $fileFullPathName "$date_ - Summary:"
Add-Content $fileFullPathName "$date_ -   resource group destination hub: $destination_rgNamehubName"
Add-Content $fileFullPathName "$date_ -   destination hub vnet..........: $destination_hubvnetName"
Add-Content $fileFullPathName "$date_ -   resource group spoke vnet.....: $rgNamespokeName"
Add-Content $fileFullPathName "$date_ -   destination spoke vnet........: $spokevnetName"
Add-Content $fileFullPathName "$date_ -   resource group origin hub.....: $origin_rgNamehubName"
Add-Content $fileFullPathName "$date_ -   origin hub vnet...............: $origin_hubvnetName"
Add-Content $fileFullPathName "$date_ -   peering name destination hub-to-spoke: $destination_spokevnetPeeringName"
Add-Content $fileFullPathName "$date_ -   peering name spoke-to-destination hub: $origin_hubvnetPeeringName"
####

# check if the destination vnet and the spoke vnet have a Gatewaysubnet
$flagdestination_hub = $false
$flagspoke = $false
foreach ($i in $destination_hubvnet.Subnets) {
    if ($i.Name -eq "Gatewaysubnet") { 
        $flagdestination_hub = $true 
    }
}
foreach ($i in $spokevnet.Subnets) {
    if ($i.Name -eq "Gatewaysubnet") { 
        $flagspoke = $true
    }
}

$StartTimeGlobal= Get-Date
$StartTime = $StartTimeGlobal
if (($flagdestination_hub -eq $true) -and ($flagspoke -eq $false)) {
    try {
        $date_ = Get-Date
        Write-Host "$date_ - start creation of NEW peering: $destination_hubvnetPeeringName in the hub vnet: $destination_hubvnetName" 
        Add-Content $fileFullPathName "$date_- start creation of NEW peering: $destination_hubvnetPeeringName in the hub vnet: $destination_hubvnetName"
        $destination_hubvnet = get-AzVirtualNetwork -Name $destination_hubvnetName -ResourceGroupName $destination_rgNamehubName
        $spokevnet = get-AzVirtualNetwork -Name $spokevnetName -ResourceGroupName $rgNamespokeName 
        # add the destination peering hub-to-spoke.
        Add-AzVirtualNetworkPeering -Name $destination_hubvnetPeeringName -VirtualNetwork $destination_hubvnet -RemoteVirtualNetworkId $spokevnet.Id -AllowForwardedTraffic
        $destination_hubvnetPeering = Get-AzVirtualNetworkPeering  -Name $destination_hubvnetPeeringName -VirtualNetwork $destination_hubvnetName -ResourceGroupName $destination_rgNamehubName
        Write-Host "$date_ - end creation NEW peering: $destination_hubvnetPeeringName in the hub vnet: $destination_hubvnetName" 
        Add-Content $fileFullPathName "$date_ - end creation NEW peering: $destination_hubvnetPeeringName in the hub vnet: $destination_hubvnetName"
    }
    catch {
        $date_ = Get-Date
        write-host "$date_ - error to create the NEW peering: $destination_hubvnetPeeringName in the the hub: $destination_hubvnetName" -ForegroundColor Red
        write-host "$date_ - Exit" -ForegroundColor Red
        Add-Content $fileFullPathName "$date_ - error to create the NEW peering: $destination_hubvnetPeeringName in the the hub: $destination_hubvnetName"
        Add-Content $fileFullPathName "$date_ - Exit"
        Exit
    }

    try {
        Write-Host "$date_ - start creation of NEW PEERING: $destination_spokevnetPeeringName in the spoke vnet: $spokevnetName" 
        Add-Content $fileFullPathName "$date_- start creation of NEW PEERING: $destination_spokevnetPeeringName in the spoke vnet: $spokevnetName"
        $destination_hubvnet = get-AzVirtualNetwork -Name $destination_hubvnetName -ResourceGroupName $destination_rgNamehubName
        $spokevnet = get-AzVirtualNetwork -Name $spokevnetName -ResourceGroupName $rgNamespokeName  
        # add the destination peering spoke-to-hub
        Add-AzVirtualNetworkPeering -Name $destination_spokevnetPeeringName -VirtualNetwork $spokevnet -RemoteVirtualNetworkId $destination_hubvnet.Id -AllowForwardedTraffic
        $destination_spokevnetPeering = Get-AzVirtualNetworkPeering -Name $destination_spokevnetPeeringName -VirtualNetwork $spokevnetName -ResourceGroupName $rgNamespokeName
        Write-Host "$date_ - end creation NEW peering: $destination_spokevnetPeeringName in the spoke vnet: $spokevnetName" 
        Add-Content $fileFullPathName "$date_ - end creation NEW peering: $destination_spokevnetPeeringName in the spoke vnet: $spokevnetName"
    }
    catch {
        write-host "error to create the NEW peering: $destination_spokevnetPeeringName in the the spoke: $spokevnetName" -ForegroundColor Red
        write-host "$date_ - Exit" -ForegroundColor Red
        Add-Content $fileFullPathName "$date_ - error to create the NEW peering: $destination_spokevnetPeeringName in the the spoke: $spokevnetName"
        Add-Content $fileFullPathName "$date_ - Exit"
        Exit
    }
}
else {
    $date_ = Get-Date
    Write-Host "$date_ - hub vnet: $destination_hubvnetName does not contain the GatewaySubnet" -ForegroundColor Red
    Write-Host "$date_ - check the subnets in the hub vnet: $destination_hubvnetName" -ForegroundColor Red
    Add-Content $fileFullPathName "$date_ - hub vnet: $destination_hubvnetName does not contain the GatewaySubnet"
    Add-Content $fileFullPathName "$date_ - check the subnets in the hub vnet: $destination_hubvnetName"
    Add-Content $fileFullPathName "$date_ - Exit"
    Exit
}

$EndTime = Get-Date
$TimeDiff = New-TimeSpan $StartTime $EndTime
$Mins = $TimeDiff.Minutes
$Secs = $TimeDiff.Seconds
$RunTime = '{0:00}:{1:00} (M:S)' -f $Mins, $Secs
Write-Host "$(Get-Date) - runtime to CREATE the NEW hub-spoke peering: $RunTime" -ForegroundColor Yellow
Write-Host "--------------------------------------------------"
Add-Content $fileFullPathName "$(Get-Date) - runtime to CREATE the NEW hub-spoke peering: $RunTime"
Add-Content $fileFullPathName "--------------------------------------------------"

################################################# DELETE origin peering hub-spoke
Write-Host "$(Get-Date) - start process of deletion of origin hub-spoke peering" -ForegroundColor Green
Add-Content $fileFullPathName "$(Get-Date) - start process of deletion of origin hub-spoke peering"
$StartTime = Get-Date

try {
    $date_ = Get-Date
    # get origin hub vnet
    $origin_hubvnet = get-AzVirtualNetwork -Name $origin_hubvnetName -ResourceGroupName $origin_rgNamehubName 
    # get spoke vnet
    $spokevnet = get-AzVirtualNetwork -ResourceGroupName $rgNamespokeName -Name $spokevnetName 
    # get the peering between origin hub-to-spoke and spoke-to-origin hub
    $origin_hubvnetPeering = Get-AzVirtualNetworkPeering -Name $origin_hubvnetPeeringName -VirtualNetwork $origin_hubvnetName -ResourceGroupName $origin_rgNamehubName
    $origin_spokevnetPeering = Get-AzVirtualNetworkPeering -Name $origin_spokevnetPeeringName -VirtualNetwork $spokevnetName -ResourceGroupName $rgNamespokeName
    $origin_hubvnetAddressSpace = $origin_hubvnet.AddressSpace.AddressPrefixesText

    Write-Host "$date_ - getting ORIGIN hub vnet: $origin_hubvnetName" -ForegroundColor Green
    Write-Host "$date_ - getting spoke vnet.....: $spokevnetName"  -ForegroundColor Green
    Write-Host "$date_ - getting PEERING NAME from ORIGIN hub-to-spoke: $origin_hubvnetPeeringName" -ForegroundColor Green
    Write-Host "$date_ - getting PEERING NAME from spoke-to-ORIGIN hub: $origin_spokevnetPeeringName" -ForegroundColor Green
    Add-Content $fileFullPathName "$date_ - getting ORIGIN hub vnet: $origin_hubvnetName"
    Add-Content $fileFullPathName "$date_ - getting spoke vnet: $spokevnetName"
    Add-Content $fileFullPathName "$date_ - getting PEERING NAME from ORIGIN hub-to-spoke: $origin_hubvnetPeeringName"
    Add-Content $fileFullPathName "$date_ - getting PEERING NAME from spoke-to-ORIGIN hub: $origin_spokevnetPeeringName"
}
catch {
    write-host "$date_ - ERROR to fetch ORIGIN hub vnet: $origin_hubvnetName , spoke vnet: $spokevnetName , peering: $origin_hubvnetPeeringName | $origin_spokevnetPeeringName" -ForegroundColor Red
    write-host "$date_ - Exit" -ForegroundColor Red
    Add-Content $fileFullPathName "$date_ - ERROR to fetch ORGIN hub vnet: $origin_hubvnetName , spoke vnet: $spokevnetName , peering: $origin_hubvnetPeeringName | $origin_spokevnetPeeringName"
    Add-Content $fileFullPathName "$date_ - Exit"
    Exit
}

try {
    $date_ = Get-Date
    Write-Host  "$date_ - REMOVING VNET PEERING in origin hub: $origin_hubvnetName" -ForegroundColor Green
    Add-Content $fileFullPathName "$date_ - REMOVING VNET PEERING in origin hub: $origin_hubvnetName"
    # remove Peer origin hub to spoke.
    Remove-AzVirtualNetworkPeering -Name $origin_hubvnetPeering.Name -VirtualNetworkName  $origin_hubvnet.Name -ResourceGroupName $origin_rgNamehubName -Force -ErrorAction Stop
}
catch {
    Write-Host "$date_ - ERROR REMOVING VNET PEERING in origin hub: $origin_hubvnetName" -ForegroundColor Red
    Add-Content $fileFullPathName "$date_ - ERROR REMOVING VNET PEERING in origin hub: $origin_hubvnetName"
}
try {
    $date_ = Get-Date
    Write-Host  "$date_ - start REMOVING ORIGIN PEERING: $origin_spokevnetPeeringName in spoke vnet: $origin_hubvnetName" -ForegroundColor Green
    Add-Content $fileFullPathName "$date_ - start REMOVING ORIGIN PEERING: $origin_spokevnetPeeringName in spoke vnet: $origin_hubvnetName"
    # remove Peer spoke to hub.
    Remove-AzVirtualNetworkPeering -Name $origin_spokevnetPeering.Name -VirtualNetworkName  $spokevnet.Name -ResourceGroupName $rgNamespokeName -Force
    Write-Host  "$date_ - end REMOVING ORIGIN PEERING: $origin_spokevnetPeeringName in spoke vnet: $origin_hubvnetName" -ForegroundColor Green
    Add-Content $fileFullPathName "$date_ - end REMOVING ORIGIN PEERING: $origin_spokevnetPeeringName in spoke vnet: $origin_hubvnetName"
}
catch {
    Write-Host "$date_ - ERROR REMOVING ORIGIN PEERING in spoke hub: $spokevnetName" -ForegroundColor Red
    Add-Content $fileFullPathName "$date_ - ERROR REMOVING ORIGIN PEERING in spoke hub: $spokevnetName"
}

$EndTime = Get-Date
$TimeDiff = New-TimeSpan $StartTime $EndTime
$Mins = $TimeDiff.Minutes
$Secs = $TimeDiff.Seconds
$RunTime = '{0:00}:{1:00} (M:S)' -f $Mins, $Secs
Write-Host "$(Get-Date) - runtime to DELETE the peering origin hub-spoke: $RunTime" -ForegroundColor Yellow
Write-Host "--------------------------------------------------"
Add-Content $fileFullPathName "$(Get-Date) - runtime to DELETE the peering origin hub-spoke: $RunTime"
Add-Content $fileFullPathName "--------------------------------------------------"

$StartTime = Get-Date
$date_ = $StartTime
write-host "$date_ - setting ALLOW GATEWAY TRANSIT in the new hub vnet + USER REMOTE GATEWAY in the spoke vnet" -ForegroundColor Cyan
Add-Content $fileFullPathName "$date_ - setting ALLOW GATEWAY TRANSIT in the new hub vnet + USER REMOTE GATEWAY in the spoke vnet"

try {
    $date_ = Get-Date
    write-host "$date_ - getting peering - hub: $destination_hubvnetPeeringName , spoke:$destination_spokevnetPeeringName" -ForegroundColor Cyan
    Add-Content $fileFullPathName "$date_ - getting peering - hub: $destination_hubvnetPeeringName , spoke:$destination_spokevnetPeeringName"
    $destination_hubvnetPeering = Get-AzVirtualNetworkPeering -Name $destination_hubvnetPeeringName -VirtualNetwork $destination_hubvnetName -ResourceGroupName $destination_rgNamehubName
    $destination_spokevnetPeering = Get-AzVirtualNetworkPeering -Name $destination_spokevnetPeeringName -VirtualNetwork $spokevnetName -ResourceGroupName $rgNamespokeName
}
catch {
    $date_ = Get-Date
    write-host "$date_ - ERROR to fetch peering in the destination hub: $destination_hubvnetPeeringName and in the spoke: $destination_spokevnetPeeringName" -ForegroundColor Red
    write-host "$date_ - Exit" -ForegroundColor Red
    Add-Content $fileFullPathName "$date_ - ERROR to fetch peering in the destination hub: $destination_hubvnetPeeringName and in the spoke: $destination_spokevnetPeeringName"
    Add-Content $fileFullPathName "$date_ - Exit"
    Exit
}

if ($null -eq $destination_hubvnetPeering) {
    $date_ = Get-Date
    write-host "$date_ - vnet peering destination hub: $destination_hubvnetPeeringName NOT FOUND!" -ForegroundColor Red
    write-host "$date_ - check vnet peering name in the input variable: $destination_hubvnetPeeringName" -ForegroundColor Red
    write-host "$date_ - Exit" -ForegroundColor Red
    Add-Content $fileFullPathName "$date_ - vnet peering destination hub: $destination_hubvnetPeeringName NOT FOUND!"
    Add-Content $fileFullPathName "$date_ - check vnet peering name in the input variable: $destination_hubvnetPeeringName"
    Add-Content $fileFullPathName "$date_ - Exit"
    Exit 
}
if ($null -eq $destination_spokevnetPeering) {
    $date_ = Get-Date
    write-host "$date_ - vnet peering destination hub: $destination_spokevnetPeeringName NOT FOUND!" -ForegroundColor Red
    write-host "$date_ - check vnet peering name in the input variable: $destination_spokevnetPeeringName" -ForegroundColor Red
    write-host "$date_ - Exit" -ForegroundColor Red
    Add-Content $fileFullPathName "$date_ - vnet peering destination hub: $destination_spokevnetPeeringName NOT FOUND!"
    Add-Content $fileFullPathName "$date_ - check vnet peering name in the input variable: $destination_spokevnetPeeringName"
    Add-Content $fileFullPathName "$date_ - Exit"
    Exit 
}

try {
    $date_ = Get-Date
    Write-Host "$date_ - start setting ALLOW GATEWAY TRANSIT in the peering: $destination_hubvnetPeeringName" -ForegroundColor Cyan
    Add-Content $fileFullPathName "$date_ - start setting ALLOW GATEWAY TRANSIT in the peering: $destination_hubvnetPeeringName"
    # set the attribute in the destination hub vnet
    $destination_hubvnetPeering.AllowGatewayTransit = $True
    # commit the change
    Set-AzVirtualNetworkPeering -VirtualNetworkPeering $destination_hubvnetPeering
    $date_ = Get-Date
    Write-Host "$date_ - OPERATION COMPLETED - ALLOW GATEWAY TRANSIT in the peering: $destination_hubvnetPeeringName" -ForegroundColor Cyan
    Add-Content $fileFullPathName "$date_ - OPERATION COMPLETED - ALLOW GATEWAY TRANSIT in the peering: $destination_hubvnetPeeringName"
}
catch {
    $date_ = Get-Date
    Write-Host "$date_ - ERROR to set ALLOW GATEWAY TRANSIT in the peering: $destination_hubvnetPeeringName" -ForegroundColor Red
    Write-Host "$date_ - Exit" -ForegroundColor Red
    Add-Content $fileFullPathName "$date_ - ERROR to set ALLOW GATEWAY TRANSIT in the peering: $destination_hubvnetPeeringName"
    Add-Content $fileFullPathName "$date_ - Exit"
    Exit
}
try {
    $date_ = Get-Date
    Write-Host "$date_ - start setting USE REMOTE GATEWAY in the peering: $destination_spokevnetPeeringName" -ForegroundColor Cyan
    Add-Content $fileFullPathName "$date_ - start setting USE REMOTE GATEWAY in the peering: $destination_spokevnetPeeringName"
    # set the attribute in the destination spoke vnet peering
    $destination_spokevnetPeering.UseRemoteGateways = $True
    # commit the change
    Set-AzVirtualNetworkPeering -VirtualNetworkPeering $destination_spokevnetPeering
    $date_ = Get-Date
    Write-Host "$date_ - OPERATION COMPLETED - USE REMOTE GATEWAY in the peering: $destination_spokevnetPeeringName" -ForegroundColor Cyan
    Add-Content $fileFullPathName "$date_ - OPERATION COMPLETED - USE REMOTE GATEWAY in the peering: $destination_spokevnetPeeringName"
}
catch {
    $date_ = Get-Date
    Write-Host "$date_ - ERROR to set USE REMOTE GATEWAY in the peering: $destination_spokevnetPeeringName" -ForegroundColor Red
    Write-Host "$date_ - Exit" -ForegroundColor Red
    Add-Content $fileFullPathName "$date_ - ERROR to set USE REMOTE GATEWAY in the peering: $destination_spokevnetPeeringName"
    Add-Content $fileFullPathName "$date_ - Exit"
    Exit
}

$EndTime = Get-Date
$TimeDiff = New-TimeSpan $StartTime $EndTime
$Mins = $TimeDiff.Minutes
$Secs = $TimeDiff.Seconds
$RunTime = '{0:00}:{1:00} (M:S)' -f $Mins, $Secs
$date_ = Get-Date
Write-Host "$date_ - runtime to execute ALLOW GATEWAY TRANSIT in the new hub vnet + USER REMOTE GATEWAY in the spoke vnet: $RunTime" -ForegroundColor Yellow
Write-Host "--------------------------------------------------"
Add-Content $fileFullPathName "$date_ - runtime to execute ALLOW GATEWAY TRANSIT in the new hub vnet + USER REMOTE GATEWAY in the spoke vnet: $RunTime"
Add-Content $fileFullPathName "--------------------------------------------------"

$EndTimeGlobal = Get-Date
$TimeDiff = New-TimeSpan $StartTimeGlobal $EndTimeGlobal
$Mins = $TimeDiff.Minutes
$Secs = $TimeDiff.Seconds
$RunTime = '{0:00}:{1:00} (M:S)' -f $Mins, $Secs
Write-Host "$EndTimeGlobal - migration vnet peering hub-to-spoke completed in TOTAL runtime: $RunTime" -ForegroundColor Yellow
Add-Content $fileFullPathName "$EndTimeGlobal - migration vnet peering hub-to-spoke completed in TOTAL runtime: $RunTime"
