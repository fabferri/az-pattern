<properties
pageTitle= 'SFTP in Azure Blob Storage with access though private endpoint'
description= "SFTP in Azure Blob Storage with private endpoint"
documentationcenter: na
services=""
documentationCenter="na"
authors="fabferri"
manager=""
editor=""/>

<tags
   ms.service="configuration-Example-Azure"
   ms.devlang="na"
   ms.topic="article"
   ms.tgt_pltfrm="na"
   ms.workload="na"
   ms.date="08/04/2022"
   ms.author="fabferri" />

# SFTP in Azure Blob Storage with access though private endpoint
The network diagram is shown below:

[![1]][1]


The vnet1 has three subnets: 
- **clientSubnet**: it is the consumer subnet
- **privateEndpointSubnet**: it is subnet to deploy the private endpoint for the storage blob
- **AzureBastionSubnet**: it is the Azure bastion subnet

<br>

The configuration aims to use the SFTP support for Azure Blob Storage with private access only.<br>
The SFTP service is associated with storage blob. <br>
The access to the storage account is kept private by storage firewall; this is specified in ARM template: 
```console
"properties": {
                "accessTier": "Hot",
                "allowBlobPublicAccess": false,
                "publicNetworkAccess": "Disabled",
                "isLocalUserEnabled": true,
                "isSftpEnabled": true,
                "isHnsEnabled": true,
                "networkAcls": {
                    "resourceAccessRules": [],
                    "bypass": "AzureServices",
                    "virtualNetworkRules": [],
                    "ipRules": [],
                    "defaultAction": "Deny"
                },
                ....
```

A private endpoint is created in the vnet to access with private connections to the storage blob.


## <a name="SFTP service"></a>1. SFTP service headline

* Azure Blob Storage doesn't support Azure Active Directory (Azure AD) authentication. SFTP utilizes a new form of identity management called **local users**
*  **local users** authentication must use either a password or a SSH private key credential. In our example we use authentication with password.
* You <ins>cannot</ins> set custom passwords, rather **Azure generates one for you**. 
* If you choose password authentication, then your password will be provided after you finish configuring a local user. Make sure to copy that password and save it in a location where you can find it later. You won't be able to retrieve that password from Azure again. 
* If you lose the password, you'll have to generate a new one. For security reasons, you can't set the password yourself.

After deployment of the ARM template the SFTP user is created, but the setup is not completed. Few steps are still required to enable **local user**; those steps can be completed through the Azure management portal. <br>

In Azure storage account, select the SFTP service: 
[![2]][2]

Select the authentication type (password or SSH key):
[![3]][3]

Verifying the blob container folder, permission and landing directory:
[![4]][4]

Grab the password for the SFTP user:
[![5]][5]

## <a name="SFTP service"></a>2. How to access in SFTP 
From the Azure VMs you can connect to Azure Blob Storage by using the SFTP:

```
sftp STORAGE_ACCOUNT_NAME.USERNAME@STORAGE_ACCOUNT_NAME.blob.core.windows.net
```
replace:
- _**STORAGE_ACCOUNT_NAME**_ with name of your Azure storage account
- _**USERNAME**_ with the name of your user.
 
The naming resolution is executed in the vnet through the private DNS zone. In the Azure VMs you can check the naming resolution by **nslookup**:
```console
nslookup  STORAGE_ACCOUNT_NAME.blob.core.windows.net
```
Replace _**STORAGE_ACCOUNT_NAME**_ with name of your Azure storage account. <br>
Inside the Azure VMs, the nslookup translate  _**STORAGE_ACCOUNT_NAME**_.blob.core.windows.net into 10.0.0.36, as defined in the A record present in DNS private zone:
```console
nslookup storaaaaaaabbbbcccc.blob.core.windows.net
Server:  UnKnown
Address:  168.63.129.16

Non-authoritative answer:
Name:    storaaaaaaabbbbcccc.privatelink.blob.core.windows.net
Address:  10.0.0.36
Aliases:  storaaaaaaabbbbcccc.blob.core.windows.net
```

You can also verify that access from internet to the SFTP is denied.


## <a name="List of files"></a>3. List of files 
| file                  | Description                                                  | 
| --------------------- |------------------------------------------------------------- | 
| **init.json**         | input parameter file to set Azure subscription, Resource Group name, Azure region, SFTP username, VMs administrator credential|
| **az-sftp.json**      | ARM template to deploy VNet, storage account, SFTP service associated with storage blob and private endpoint|
| **az-sftp.ps1**       | powershel script to deploy **az-sftp.json**                       |

Strcuture of the file **init.json**:
```console
{
    "subscriptionName": NAME_OF_AZURE_SUBSCRIPTION
    "ResourceGroupName": NAME_OF_RESOURCE_GROUP,
    "userName": NAME_OF_SFTP_USER,
    "homeDirectory": SFTP_ROOT_FOLDER,
    "location": AZURE_REGION,
    "adminUsername": ADMINISTRATOR_USERNAME_VMs,
    "adminPassword": ADMINISTRATOR_PASSWORD_VMs
}
```


`Tags: Azure storage, SFTP, Azure private endpoint` <br>
`date: 04-08-22`


<!--Image References-->

[1]: ./media/network-diagram.png "network diagram"
[2]: ./media/sftp01.png "SFTP service"
[3]: ./media/sftp02.png "authentication type: password or SSH key)"
[4]: ./media/sftp03.png "blob container folder, permission and landing directory"
[5]: ./media/sftp04.png "grab SFTP password"

<!--Link References-->

