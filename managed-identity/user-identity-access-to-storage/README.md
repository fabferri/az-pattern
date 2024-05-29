<properties
pageTitle= 'user-assigned managed identity to access to Azure Storage'
description= "user-assigned managed identity to access to Azure Storage"
documentationcenter: na
services="Azure VPN"
documentationCenter="na"
authors="fabferri"
manager=""
editor="fabferri"/>

<tags
   ms.service="configuration-Example-Azure"
   ms.devlang="na"
   ms.topic="article"
   ms.tgt_pltfrm="Azure"
   ms.workload="na"
   ms.date="28/05/2024"
   ms.author="fabferri" />

# User-assigned managed identity to access to Azure Storage
**Managed Service Identity** (**MSI**) provides an identity for applications to use when connecting to resources that support Azure Active Directory (Azure AD) authentication.
Applications may use the managed identity to obtain Azure AD tokens. You can use managed identities to authenticate to any resource that supports Azure AD authentication.
This article discusses how to use a user-assigned managed identity for a Linux virtual machine (VM) to access Azure Storage. 

[![1]][1]

The ARM template makes the following actions:
- Creates a storage account. The property **"allowSharedKeyAccess": false** restricts access to the storage account via primary key, secondary key, and SAS. Disabling access by keys and SAS also prevents access to the storage blob through the Azure management portal. 
- Create a user-assigned identity
- Assign to user managed identity multiple built-in roles:
   * **Contributor** 
   * **Storage Account Contributor**
   * **Storage Blob Data Owner** <br>

  Each role has a scope restricted to the resource group  **"scope":"[resourceGroup().id]"**. if you want to restrict the scope to the resource group, you can modify the scope as: **"scope": "[concat('Microsoft.Storage/storageAccounts', '/', parameters('storageAccountName'))]"**
- Create an ubuntu VM and associated the user-identity with the VM 
- By custom script extension install in the ubuntu VM the Azure CLI


## <a name="Access to the storage account"></a>1. Access to the storage account from the Azure VM
Managed identities eliminate the need for manual credential management. On resources configured for managed identities for Azure resources, you can sign in using the managed identity. <br>

After deployment login in Ubuntu Azure VM and run the following Azure CLI commands:
```bash
# login with user-assigned managed identity. 
# If the resource should have multiple user assigned managed identities and no system assigned identity, 
# you must specify the client ID or object ID or resource ID of the user assigned managed identity 
# with --username for login as in the following syntax:
#
# az login --identity --username <client_id|object_id|resource_id>
#
# In our case we have a single user-assigned managed identity therfore the --username is not required.
az login --identity
az storage account list


# capture the name of the resource group e load the name in the bash variable 'rg'
rg=$(az group list --query "[].name" -o tsv)

# different ways for filtering the storage account
az storage account list --query "[].id"
az storage account list --resource-group $rg --query "[*].{Name:name,Location:primaryLocation,Kind:kind}" --output table
az storage account list --resource-group $rg --query "[*].{Name:name}" 
az storage account list --resource-group $rg --query "[].name" -o tsv

# assign a name of storage account to the variable storageAccount
storageAccount=$(az storage account list --resource-group $rg --query "[].name" -o tsv)

# specify the name of container in the storage account
containerName='home1'

#create the container in storage account
az storage container create --name $containerName --account-name $storageAccount --auth-mode login

#show the container name created
az storage container list --account-name $storageAccount --auth-mode login --query "[].name" -o tsv

# delete the storage container
az storage container delete --name $containerName --account-name $storageAccount --auth-mode login

# re-create the container in storage account
# note: the command of re-creation might return a "created": false.
# this happens because the operation of delete of container is async.
# you need to repeat the same command still you see the return operation value as "created": true
az storage container create --name $containerName --account-name $storageAccount --auth-mode login

# create a local file in the VM
touch 1.txt
cat <<EOF > 1.txt
------------- beginning file ------------- 
test10000000000000000000
test10000000000000000001 
test10000000000000000002
test10000000000000000003
test10000000000000000004
test10000000000000000005
------------- end of file ------------- 
EOF

# Create in the ubuntu VM a text file.
# assign to the bash variable 'localFile' the name of file we want to create
localFile='1.txt'
#Upload a single named file
az storage blob upload \
    --file $localFile \
    --container-name $containerName \
    --account-name $storageAccount \
    --auth-mode login

# List all blobs in a named container named $containerName
az storage blob list --container $containerName --account-name $storageAccount --auth-mode login
az storage blob list --container $containerName --account-name $storageAccount --auth-mode login --query "[].name" -o tsv

# Download the storage blob to a local text file
# Create a new bash variable for a new filename
file2='2.txt'
sourceBlobName='1.txt'
az storage blob download --account-name $storageAccount --container-name $containerName --name $sourceBlobName  --auth-mode login --file $file2 
```


`NOTE`
if you want to check the execution of custom script extension, check the logs in the folder:
```bash
sudo ls -l /var/lib/waagent/custom-script/download/0/
sudo cat /var/log/waagent.log
```

`Tags: user-assigned managed identity` <br>
`date: 28-05-2024` <br>

<!--Image References-->

[1]: ./media/network-diagram.png "network diagram" 

<!--Link References-->

