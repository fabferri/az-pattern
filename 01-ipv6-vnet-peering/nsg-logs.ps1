#
# Reference:
#  https://docs.microsoft.com/en-us/azure/network-watcher/traffic-analytics
#  https://docs.microsoft.com/en-us/azure/network-watcher/network-watcher-nsg-flow-logging-powershell
#
$subscriptionName = "AzureDemo3"              # Azure subscription name
$rgNSG            = "ipv6-1"                  # resource group NSG-Network Security Group
$nsgName          = "nsgSpoke1"               # Name of NSG
$rgNW             = "NetworkWatcherRG"        # resource group network watcher
$nwName           = "NetworkWatcher_uksouth"  # network watcher name
$locationNW       = "uksouth"                 # location network watcher
$rgStorage        = "nsglog01"                # resource group of storage account used to store logs

$subscr=Get-AzSubscription -SubscriptionName $subscriptionName
Select-AzSubscription -SubscriptionId $subscr.Id



try {
#Retrieve the network security group that you want to enable diagnostic logging
$nsg=Get-AzNetworkSecurityGroup `
  -Name $nsgName `
  -ResourceGroupName $rgNSG -ErrorAction Stop
  write-host "find out the Network Security Group: "$nsgName " in the resource group: "$rgNSG -ForegroundColor Yellow
} catch {
  write-host "resource group:"$rgNSG " doesn't exist!" -ForegroundColor Yellow
  write-host "please reference one existing resource group and run again" -ForegroundColor Yellow
  Exit
}


try {     
    Get-AzResourceGroup -Name $rgNW -Location $locationNW -ErrorAction Stop     
    Write-Host "Resource Group: "$rgNW " for the Network Watcher already exists... skipping" -foregroundcolor Green -backgroundcolor Black
} catch {     
    $rg = New-AzResourceGroup -Name $rgNW -Location $locationNW  -Force
}

#Register Insights provider
Register-AzResourceProvider -ProviderNamespace Microsoft.Insights


#generate a unique name for the storage account
$tail=([guid]::NewGuid().tostring()).replace("-","").Substring(0,8)
$storageAccountName = "nsglog"+ $tail

# create a storage account if it doesn't exist
$s=Get-AzStorageAccount -ResourceGroupName $rgNW   # $rgStorage 
# check if $s has $null as value
if (!$s) { 
   # create a new storage account
   try { 
       $storageAccount =Get-AzStorageAccount -ResourceGroupName $rgNW –StorageAccountName $storageAccountName -ErrorAction Stop
        Write-Host 'Storage account'$storageAccount.Name 'already exists... skipping' -foregroundcolor Yellow -backgroundcolor Black
   } 
   catch{      
       # Create a new storage account.
       $storageAccount =New-AzStorageAccount `
                -ResourceGroupName $rgNW `
                –StorageAccountName $storageAccountName `
                -Location $locationNW  -SkuName Standard_LRS -Kind StorageV2 -AccessTier Hot 
           
       Write-Host "Create the storage account: "$storageAccount.StorageAccountName -foregroundcolor Yellow -backgroundcolor Black
   }
} 
else {
  $storageAccount = $s[0]
}

#get the storage context
$ctx=$storageAccount.Context



#Enable Network Security Group Flow logs and Traffic Analytics
#To create an instance of Network Watcher
try{
  $NW = Get-AzNetworkWatcher -Name $nwName -ResourceGroup $rgNW   -ErrorAction Stop
   Write-Host 'Network Flow: '$nwName ' already exists' -foregroundcolor Yellow -backgroundcolor Black
  
} catch {
   Write-Host 'Create Network Flow: '$nwName  -foregroundcolor Yellow -backgroundcolor Black
    New-AzNetworkWatcher -Name $nwName -ResourceGroupName $rgNW  -Location $locationNW
    $NW = Get-AzNetworkWatcher -ResourceGroupName $rgNW  -Name $nwName
}
#write-host "Flow NSG Logs status:" -ForegroundColor Yellow
#Get-AzNetworkWatcherFlowLogStatus -NetworkWatcherName $nwName -ResourceGroup $rgNW  -TargetResourceId $nsg.Id 


try{
  #Configure Version 2 Flow Logs, and configure Traffic Analytics
  Set-AzNetworkWatcherConfigFlowLog -NetworkWatcher $NW -TargetResourceId $nsg.Id -StorageAccountId $storageAccount.Id -EnableFlowLog $true -FormatType Json -FormatVersion 2
} catch {
  Write-Host 'Error in configuration of Network Watcher logs: ' -foregroundcolor Yellow -backgroundcolor Black
}


# Query the status of flow logging on a resource. 
# The status includes: 
# - whether or not flow logging is enabled for the resource provided, 
# - the configured storage account to send logs, 
# - the retention policy for the logs. 
# Currently Network Security Groups are supported for flow logging.
write-host "Flow NSG Logs status:" -ForegroundColor Yellow
Get-AzNetworkWatcherFlowLogStatus -NetworkWatcher $NW -TargetResourceId $nsg.Id


# TO DISABLE the Flow Logging uncomment the line below:
# Set-AzNetworkWatcherConfigFlowLog -NetworkWatcher $NW -TargetResourceId $nsg.Id -StorageAccountId $storageAccount.Id -EnableFlowLog $false

# TO REMOVE the Network Watcher uncomment the line below:
# Remove-AzNetworkWatcher -Name $nwName -ResourceGroup $rgNW
 