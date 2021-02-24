# Create a storage account with SAS
#
# Variables:
#    $subscriptionName: name of the azure subscription
#    $rgName: name of the resource group where is deployed the storage account
#    $location: name of the Azure region
#    $containerName: name of the storage container
#    $storageAccountType: type of storage account
#    $storagePolicyName: name of the storage policy
#    $armTemplateFile: ARM template to be copied to the storage container
#    $armTemplateParamFile: ARM paramenter file to be copied to the storge container
#
$subscriptionName = "AzDev"           
$rgName = "storage-01"             
$location = "eastus"                      
$containerName = "home"                 
$storageAccountType = "Standard_LRS"    
$storagePolicyName  = "storage-policy" 
$armTemplateFile = "ubuntuVM.json"
$armTemplateDeleteVM = "delete.json"

$blobName1 = $armTemplateFile           # define the name of storage blob to store the ARM template
$blobName2 = $armTemplateDeleteVM       # define the name of storage blob to store the ARM template to delete the VM
$pathFiles = Split-Path -Parent $PSCommandPath
$templateFile1 = "$pathFiles\$armTemplateFile"
$templateFile2 = "$pathFiles\$armTemplateDeleteVM"

# generate a unique name for the storage account
$tail=([guid]::NewGuid().tostring()).replace("-","").Substring(0,10)
$storageAccountName = "repo"+ $tail


# select the Azure subscription
$subscr=Get-AzSubscription -SubscriptionName $subscriptionName
Select-AzSubscription -SubscriptionId $subscr.Id 

# checking the resource group where is deployed the storage account
try {     
    Get-AzResourceGroup -Name $rgName -Location $location -ErrorAction Stop  
    Write-Host 'RG already exists... skipping' -foregroundcolor Yellow -backgroundcolor Black
} catch {     
    $rg = New-AzResourceGroup -Name $rgName -Location $location  -Force
}

$s=Get-AzStorageAccount -ResourceGroupName $rgName

# check if $s has $null as value
if (!$s) { 
   # create a new storage account
   try { 
       $storageAccount =Get-AzStorageAccount -ResourceGroupName $rgName  $storageAccountName -ErrorAction Stop 
        Write-Host 'Storage account'$storageAccount.StorageAccountName 'already exists... skipping' -foregroundcolor Yellow -backgroundcolor Black
   } 
   catch{
       # Create a new storage account.
       $storageAccount =New-AzStorageAccount -ResourceGroupName $rgName $storageAccountName -Location $Location -Type $storageAccountType -Kind BlobStorage -AccessTier Hot 
       Write-Host 'Create the storage account: '$storageAccount.StorageAccountName  -foregroundcolor Yellow -backgroundcolor Black
   }
} 
else {
  $storageAccount = $s[0]
}

#get the storage context
$ctx=$storageAccount.Context

#check if it exists a storage container in the storage account 
try { 
   $container=Get-AzStorageContainer -Name $containerName -Context $ctx -ErrorAction Stop
   Write-Host 'Get the storage countainer: '$containerName  -foregroundcolor Yellow -backgroundcolor Black 
} catch {
  # create a container
  $container=New-AzStorageContainer -Name $containerName  -Context $ctx 
  Write-Host 'Create a new storage container: '$containerName  -foregroundcolor Yellow -backgroundcolor Black
}
#
#
try { 
  write-host "acquire access policy: "$accessPolicy$storagePolicyName -ForegroundColor Cyan
  $accessPolicy=Get-AzStorageContainerStoredAccessPolicy -Container $containerName -Policy $storagePolicyName -Context $ctx -ErrorAction Stop
  write-host "storage access policy: "$accessPolicy -ForegroundColor Cyan
} catch {
 # Create Storage Access Policy
 $expiryTime = (Get-Date).AddYears(1)
 # There are 4 levels of permissions that can be used: read (r), Write (w), list (l) and delete (d)
 $containerAccessPolicy=New-AzStorageContainerStoredAccessPolicy -Container $containerName -Policy $storagePolicyName -Permission rwdl -ExpiryTime $expiryTime -Context $ctx
 Write-Host 'Associate the access policy to the storage container '$containerAccessPolicy  -foregroundcolor Yellow -backgroundcolor Black
}

$storageResourceURI=$container.CloudBlobContainer.Uri.AbsoluteUri

#Create Storage Access Signature (SAS) with storage policy
$sasToken = New-AzStorageContainerSASToken -Name $containerName -Policy $storagePolicyName -Context $ctx


$sasURI1=$storageResourceURI +"/"+ $blobName1 + $sasToken
$sasURI2=$storageResourceURI +"/"+ $blobName2 + $sasToken

write-host "storage container - URI......: "$storageResourceURI
write-host "storage container - SAS token: "$sasToken -foregroundcolor Yellow -backgroundcolor Black
write-host "blob ARM template - SAS URI..: "$sasURI1 -foregroundcolor Yellow -backgroundcolor Black
write-host "blob ARM delete VM- SAS URI..: "$sasURI2 -foregroundcolor Yellow -backgroundcolor Black

$a=""
$a  = "storage container - URI......: $storageResourceURI`n"
$a += "storage container - SAS token: $sasToken`n"
$a += "blob ARM template - SAS URI..: $sasURI1`n"
$a += "blob ARM paramfile- SAS URI..: $sasURI2`n"
Out-File -FilePath "$pathFiles\SAS.txt" -InputObject $a 


write-host "`nwriting ARM template adn paramenter file in the storage container" -ForegroundColor Green 

Set-AzStorageBlobContent -Container $containerName -File $templateFile1 -Context $ctx -Blob $blobName1
Set-AzStorageBlobContent -Container $containerName -File $templateFile2 -Context $ctx -Blob $blobName2

### from the storage account, get the files by SAS URI
write-host "`ndownload ARM template and paramenter file from the storage container" -ForegroundColor Green 
Invoke-WebRequest -Uri $sasURI1 -OutFile "$pathFiles\file1.json" -Verbose
Invoke-WebRequest -Uri $sasURI2 -OutFile "$pathFiles\file2.json" -v