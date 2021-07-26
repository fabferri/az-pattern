#
# Create a storage account
# 
# - Assign a policy to the storage container
# - Create a Storage Access Signature (SAS) with storage policy and associates with the storage container
#
$subscriptionName   = "Pathfinders"           ### name of the Azure subscription
$storageAccountName = "sto0account11111"      ### name of the storage account
$location           = "eastus2"               ### azure region
$rgName             = "fab-servicetag1"       ### name of the resource group
$containerName      = "folder1"               ### name of the blob storage folder
$storagePolicyName  = "storage-policy"        ### name of the policy
$fileName           = "storage-sas-value.txt"
#
#
$RGTagExpireDate = '7/29/2021'
$RGTagContact = 'user1@contoso.com'
$RGTagNinja = 'user1'
$RGTagUsage = 'testing service tag'

### select the Azure subscription
$subscr=Get-AzSubscription -SubscriptionName $subscriptionName
Select-AzSubscription -SubscriptionId $subscr.Id

$pathFiles      = Split-Path -Parent $PSCommandPath
$fullFilePath   = "$pathFiles\$fileName"



### check avaiability of storage account name
$nameAvailability=Get-AzStorageAccountNameAvailability -name $storageAccountName
if (-not $nameAvailability)
{
   write-host "storage account name $storageAccountName already allocated."
   write-host "change the name of storage account in the powershell script and run again!" -ForegroundColor Cyan 
   Exit
}

### it gets the resouce group; if it doesn't exist create a new resource group.
Try {Get-AzResourceGroup -Name $rgName -ErrorAction Stop | Out-Null}
Catch {
   write-host "$(get-date) - create a new resoruce group: $rgName"
   New-AzResourceGroup -Name $rgName -Location $location -ErrorAction Stop | Out-Null
   write-host "$(get-date) - resource group $rgName has been created"
}

# set a tag on the resource group if it doesn't exist.
if ((Get-AzResourceGroup -Name $rgName).Tags -eq $null)
{
  # Add Tag Values to the Resource Group
  Set-AzResourceGroup -Name $rgName -Tag @{Expires=$RGTagExpireDate; Contacts=$RGTagContact; Pathfinder=$RGTagNinja; Usage=$RGTagUsage} | Out-Null
}

Try { 
   write-host "$(get-date) - get a storage account: $storageAccountName"
   Get-AzStorageAccount -ResourceGroupName $rgName -Name $storageAccountName -ErrorAction Stop | Out-Null 
}
catch {
   write-host "$(get-date) - create a storage account: $storageAccountName"
   New-AzStorageAccount -ResourceGroupName $rgName -Name $storageAccountName -Location $location -SkuName Standard_LRS -Kind StorageV2
   write-host "storage account $storageAccountName has been created" -ForegroundColor Green
}

# getting storage context
$storageAccount =Get-AzStorageAccount -ResourceGroupName $rgName –StorageAccountName $storageAccountName
$ctx=$storageAccount.Context


# check if it exists a storage container in the storage account 
try { 
   write-host "$(get-date) - get the storage container: $containerName" -foregroundcolor Yellow -backgroundcolor Black 
   $container=Get-AzStorageContainer -Name $containerName -Context $ctx -ErrorAction Stop
   Write-Host "storage countainer: $containerName found" -foregroundcolor Yellow -backgroundcolor Black 
} catch {
   # create a container
   Write-Host "$(get-date) - Create a new storage container: $containerName"  -foregroundcolor Yellow -backgroundcolor Black
   $container=New-AzStorageContainer -Name $containerName  -Context $ctx  
}

try {
   Write-Host "$(get-date) - associated an access policy: $storagePolicyName to the storage container" -ForegroundColor Cyan
   Get-AzStorageContainerStoredAccessPolicy -Container $containerName -Policy $storagePolicyName -Context $ctx  -ErrorAction Stop | Out-Null
}
catch {
   $expiryTime = (Get-Date).AddYears(1)
   # There are 4 levels of permissions that can be used: read (r), Write (w), list (l) and delete (d)
   Write-Host "$(get-date) - define the permission in the access policy" -ForegroundColor Cyan
   $containerAccessPolicy=New-AzStorageContainerStoredAccessPolicy -Container $containerName -Policy $storagePolicyName -Permission rwdl -ExpiryTime $expiryTime -Context $ctx
}


#Create Storage Access Signature (SAS) with storage policy
Write-Host "$(get-date) - create a SAS token with policy: $storagePolicyName" -foreground cyan
$sasToken = New-AzStorageContainerSASToken -Name $containerName -Policy $storagePolicyName -Context $ctx

write-host $sasToken -ForegroundColor Cyan

Write-Host "$(get-date) - write the SAS to the file: $fullFilePath" -foreground cyan
Out-File -FilePath $fullFilePath -InputObject $sasToken

###example of SAS:    ?sv=2019-02-02&sr=c&si=storage-policy&sig=PWxZccOcOAHdIT9BkVnhN1TyzNhpOwAzyemLjrsJ7qM%3D
Exit


### dowload storage blob
$blobs = Get-AzStorageBlob -Container $containerName -Context $ctx 
$fileConfig="C:\"
foreach ($blob in $blobs)  
{   
   Get-AzStorageBlobContent -Container $containerName -Blob $blob.Name -Destination $fileConfig -Context $ctx -Force
}  