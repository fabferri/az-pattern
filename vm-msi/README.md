<properties
pageTitle= 'System-assigned managed identity to access to Azure Storage'
description= "System-assigned managed identity to access to Azure Storage"
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
   ms.date="26/05/2022"
   ms.author="fabferri" />

# System-assigned managed identity to access to Azure Storage
**Managed Service Identity** (**MSI**) provides an identity for applications to use when connecting to resources that support Azure Active Directory (Azure AD) authentication.
Applications may use the managed identity to obtain Azure AD tokens. You can use managed identities to authenticate to any resource that supports Azure AD authentication.
This article discusses how to use a system-assigned managed identity for a Linux virtual machine (VM) to access Azure Storage. 

[![1]][1]

Actions executed by The ARM template:
* create a storage account 
* create a blob container 'default/folder1' in a storage account
* The following roles are assigned to the system managed identity:
   * StorageBlobDataContributor
   * StorageBlobDataOwner
   * StorageBlobDataReader
* grant to the system managed identity access to the Azure Storage container
<br>

## <a name="access to the storage account"></a>1. Copy a file on the storage account
Copy a text file _myfile.txt_ in the storage account into "default/folder1" 

## <a name="access to the storage account by MSI token"></a>2. Access to the storage account from the Azure VM
When the deployment or ARM template is completed, you can access from the Azure VM to the blob storage by MSI token.
Below the list of steps to download a storage blob from storage account.

**1. install in the azure VM the command-line JSON processor:**
```bash
apt -y install jq
```

**2.Get the token:**
```bash
curl 'http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https%3A%2F%2Fstorage.azure.com%2F' -H Metadata:true
```

**3. store the token in the variable t:**
```bash
t=$(curl -s 'http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https%3A%2F%2Fstorage.azure.com%2F' -H Metadata:true | jq .access_token)
```

**4. remove the double quote character at beginning and at the end (removing first and last character from the string)**

tk="${t:1:-1}"
 
**5. access to the blob storage**
```bash
curl https://<STORAGE ACCOUNT>.blob.core.windows.net/<CONTAINER NAME>/<FILE NAME> -H "x-ms-version: 2017-11-09" -H "Authorization: Bearer <ACCESS TOKEN>"
```

Assembly all in a script:

```bash
#!/bin/bash
containerName='folder1'
fileName='myfile.txt'
storageName='stggomlxxxgtmroq'
t=$(curl -s 'http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https%3A%2F%2Fstorage.azure.com%2F' -H Metadata:true | jq .access_token)
tk="${t:1:-1}"
curl https://{$storageName}.blob.core.windows.net/{$containerName}/{$fileName} -H "x-ms-version: 2017-11-09" -H "Authorization: Bearer ${tk}"
```

Before running the bash script you need:
- install the JSON parser **jq**
- set the correct name of the storage account

**NOTE: access with MSI token to the storage blob works only in Azure VM**

<!--Image References-->

[1]: ./media/network-diagram.png "network diagram" 

<!--Link References-->

