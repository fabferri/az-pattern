$ContainerName='cert1'
$localFolder = 'C:\cert1'

$response = Invoke-WebRequest -Uri 'http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https%3A%2F%2Fmanagement.azure.com%2F' `
                              -Headers @{Metadata="true"}
                              $content =$response.Content | ConvertFrom-Json
$access_token = $content.access_token
Write-Host "The managed identities for Azure resources access token is $access_token"

# You just connected to Azure using a managed identity.
Connect-AzAccount -Identity

# get storage acocunt name and resource group name
$storageAccountName=(Get-AzStorageAccount).StorageAccountName
$resourceGroupName=(Get-AzStorageAccount).ResourceGroupName
$Context=(Get-AzStorageAccount -Name $storageAccountName -ResourceGroupName $resourceGroupName).Context

foreach ($fileName in (Get-ChildItem -File -Recurse -Path $localFolder).Name)
{
  $blob1 = @{
    File             = "$localFolder\$fileName"
    Container        = $ContainerName
    Blob             = $fileName
    Context          = $Context
    StandardBlobTier = 'Hot'
  }
  Set-AzStorageBlobContent @blob1 -Force
}