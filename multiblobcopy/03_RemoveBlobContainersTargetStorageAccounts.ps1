#############################################
#
# Remove blob containers in a list of Azure Storage accounts
#
# INPUT variables:
#
#  $subscription : Azure subscription name
#  $rgGroup      : Resource Group
#  $ContainerName: blob container name of target storage accounts
#
#
##### INPUT VARIABLES  #####################
$subscription  = "AZURE_SUBSCRITIONNAME_TARGET_STORAGE_ACCOUNT"
$rgGroup       = "RESOURCE_GROUP_TARGET_STORAGE_ACCOUNT"
$ContainerName = "vhds"
#############################################

#Empty hash table. It is used to store a list of Azure storage accounts
$deststorage=@()

### Acquire a list of Azure Storage account and load in the $deststorage hash table
function GetListStorageAccounts 
{
    param(  [Parameter(Mandatory=$true)] [System.String]$subscriptiom,
            [Parameter(Mandatory=$true)] [System.String]$rg)
    
    
    Get-AzureRmSubscription -SubscriptionName $subscriptiom |Select-AzureRmSubscription
    $StorageAccountList=Get-AzureRmStorageAccount -ResourceGroupName $rg
    foreach ($StorageAccount in $StorageAccountList) 
    { 
         $StorageAccountName = $StorageAccount.StorageAccountName
         $StorageAccountKey = Get-AzureRmStorageAccountKey -ResourceGroupName $rg -Name $StorageAccountName  
         $primaryKey=$StorageAccountKey[$StorageAccountKey.KeyName.IndexOf("key1")].Value.ToString()

         write-host -foregroundcolor yellow "dest-Name:" $StorageAccountName
         write-host -foregroundcolor Green  "dest-Key :" $primaryKey
         
         $Global:deststorage += ,@($StorageAccountName,$primaryKey)   
    }
}

function RemoveBlobContainer
{

        foreach ($storage in  $global:deststorage.GetEnumerator())
        {
           $StorageAccountName = $storage[0]
           $StorageAccountKey  = $storage[1]
           write-host -ForegroundColor cyan "->Storage account:" $StorageAccountName "-" $StorageAccountKey

           $ctx = New-AzureStorageContext -StorageAccountName $StorageAccountName -StorageAccountKey $StorageAccountKey
           
           $blobcontainer = Get-AzureStoragecontainer  -Container $ContainerName -Context $Ctx -ErrorAction Ignore

           if ($blobcontainer -ne $null)
           {
               write-host "remove blob container:" $ContainerName "from storage account:" $StorageAccountName
               Remove-AzureStorageContainer -Context $ctx -Name $ContainerName -Force -Verbose
               write-host ""
           }
        }
}
GetListStorageAccounts $subscription $rgGroup
RemoveBlobContainer $deststorage