<properties
pageTitle= 'user-assigned managed identity to access to Azure Keyvault'
description= "user-assigned managed identity to access to Azure Keyvault"
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

# User-assigned managed identity to access to Azure Keyvault
**Managed Service Identity** (**MSI**) provides an identity for applications to use when connecting to resources that support Azure Active Directory (Azure AD) authentication. Applications may use the managed identity to obtain Azure AD tokens. You can use managed identities to authenticate to any resource that supports Azure AD authentication. This article discusses how to use a user-assigned managed identity for a Linux virtual machine (VM) to access Azure KeyVault. 

[![1]][1]

**Basic facts about RBAC** <br>
- Azure role-based access control (Azure RBAC) is an authorization system built on Azure Resource Manager that provides centralized access management of Azure resources.
- Azure RBAC allows users to manage Key, Secrets, and Certificates permissions. It provides one place to manage all permissions across all key vaults. <br>
- The Azure RBAC model allows users to set permissions on different scope levels: management group, subscription, resource group, or individual resources.

As reported in the [documentation](https://learn.microsoft.com/en-gb/azure/key-vault/general/security-features?WT.mc_id=Portal-Microsoft_Azure_KeyVault#access-model-overview): <br>
`Access to a key vault is controlled through two interfaces:` 
- **the management plane** The management plane is where you manage Key Vault itself. Operations in this plane include creating and deleting key vaults, retrieving Key Vault properties, and updating access policies.
and 
- **data plane**. The management plane is where you manage Key Vault itself. Operations in this plane include creating and deleting key vaults, retrieving Key Vault properties, and updating access policies. The data plane is where you work with the data stored in a key vault. You can add, delete, and modify keys, secrets, and certificates.`

`Both planes use Microsoft Entra ID for authentication. For authorization, the management plane uses Azure role-based access control (Azure RBAC) and the data plane uses a Key Vault access policy and Azure RBAC for Key Vault data plane operations.`

`To access a key vault in either plane, all callers (users or applications) must have proper authentication and authorization. Authentication establishes the identity of the caller. Authorization determines which operations the caller can execute. Authentication with Key Vault works in conjunction with Microsoft Entra ID, which is responsible for authenticating the identity of any given security principal.`


The ARM template creates two array variables:
- The **roleDefinitionBuiltIn** array variable contains a list of Azure built-in RBAC. <br>
- The **listRoleDefinitionBuiltIn** contains only two built-in roles for the KeyVault dataplane, **KeyVault Administrator** and **KeyVaultSecretsOfficer**
<br>

The ARM template makes the following actions: <br>
- Create a user-assigned identity
- Assignment by **"Microsoft.Authorization/roleAssignments** of the built-in **Contributor** role to the user-managed identity. The scope of assignment is the resource group: `"scope": "[resourceGroup().id]"`
- Create an Azure KeyVault in the Azure Resource Group
- Create a secret inside the KeyVault
- Assignment by **Microsoft.KeyVault/vaults/accessPolicies**  of the secret permissions ("all","list", "set", "delete", "purge") to user-managed identity to access to the secret in the Keyvault 
- The **Microsoft.Resources/deployments** allows to define a scope restricted to the Resource Group and assign through **"Microsoft.Authorization/roleAssignments** the built-in role specified in the **listRoleDefinitionBuiltIn** array to the user-managed identity
- create an ubuntu VM and associated the user-identity to the VM 
- by custom script extension install in the ubuntu VM the Azure CLI.

`Note` <br>
In **"Microsoft.Authorization/roleAssignments"** the **principalId** of the user-mamanaged identity is referenced through the following syntax:
```json
"principalId": "[reference(resourceId('Microsoft.ManagedIdentity/userAssignedIdentities', parameters('identityName')), '2023-01-31').principalId]"
```



## <a name="Access to the KeyVault"></a>1. Access to the KeyVault from the Azure VM
On resources configured for managed identities for Azure resources, you can sign in using the managed identity. Managed identities eliminate the need for manual credential management. <br>

After deployment login in Ubuntu Azure VM and run the following Azure CLI commands:
```bash
# login with user-assigned managed identity. 
# If the resource should have  multiple user assigned managed identities and no system assigned identity, 
# you must specify the client ID or object ID or resource ID of the user assigned managed identity 
# with --username for login as in the following syntax:
#
# az login --identity --username <client_id|object_id|resource_id>
#
# In our case we have a single user-assigned managed identity therfore the --username is not required.
az login --identity
az keyvault list


# capture the name of the resource group e load the name in the bash variable 'rg'
rg=$(az group list --query "[].name" -o tsv)

# different ways for filtering the keyvault
az keyvault list --query "[].id"
az keyvault list --resource-group $rg --output table
# show only the name of the keyvaults
az keyvault list --resource-group $rg --query "[].name" -o tsv
az keyvault list --resource-group $rg --query "[*]" --output table
az keyvault list --resource-group $rg --query "[*].{Name:name,location:location,rg:resourceGroup}" --output table


# assign a name of KeyVault to the variable keyvaultName
keyvaultName=$(az keyvault list --resource-group $rg --query "[].name" -o tsv)

# show the list of secret inside the keyvault
az keyvault secret list --vault-name $keyvaultName --include-managed true

# fiter the list of secret showing only the name of the secrets
az keyvault secret list --vault-name $keyvaultName --include-managed true --query "[].name" -o tsv

# create a new secret inside keyvault
az keyvault secret set --name myNewSecret --vault-name $keyvaultName --value myNewSecretVal

# visualize now two secrets
az keyvault secret list --vault-name $keyvaultName --include-managed true

# show the attributes of the secret including the secret
az keyvault secret show --vault-name $keyvaultName --name user101

# show only the secret value
az keyvault secret show --vault-name $keyvaultName --name user101 --query value -o tsv

# move the secret in soft delete
az keyvault secret delete --vault-name $keyvaultName --name myNewSecret

# purge the secret in soft delete state
az keyvault secret purge --vault-name $keyvaultName --name myNewSecret

# Get the list of deleted secretes
az keyvault secret list-deleted --vault-name $keyvaultName

# create a new secret
myLine='test10000000000000000000'
myLine+='test10000000000000000001'
myLine+='test10000000000000000002'
myLine+='test10000000000000000003'
myLine+='test10000000000000000004'
myLine+='test10000000000000000005'
az keyvault secret set --name multipleLineSecret --vault-name $keyvaultName --value $myLine


az vm image list --offer ubuntu-24_04-lts --publisher canonical --sku minimal --all --output table
# Create a ubuntu VM 
vmname="myVM"
username="azureuser"

az network public-ip create \
    --resource-group $rg \
    --name myPublicIP \
    --location uksouth

az network nic create \
    --resource-group $rg \
    --name myNic \
    --location uksouth \
    --vnet-name vnet1 \
    --subnet subnet1 \
    --public-ip-address myPublicIP 

az vm create \
    --resource-group $rg \
    --name myVM \
    --location uksouth \
    --nics myNic \
    --image Ubuntu2204 \
    --authentication-type password \
    --admin-username ADMINISTRATOR_USERNAME \
    --admin-password ADMINISTRATOR_PASSWORD
```
Before running the command to create the Azure VM, replace the string **ADMINISTRATOR_USERNAME** and **ADMINISTRATOR_PASSWORD** with your values.


if you create a secret in KeyVault and after you deleted it, the secret is not completly deleted but it moves in remove state. to full delete the keyvault:
```bash
az keyvault purge --name keyvaultname
```
or in powershell:
```
Get-AzKeyVault -InRemovedState  | Remove-AzKeyVault -InRemovedState -Force
```


`NOTE`
if you want to check the execution of custom script extension, check the logs in the folder:
```bash
sudo ls -l /var/lib/waagent/custom-script/download/0/
sudo cat /var/log/waagent.log
```


## <a name="ANNEX"></a>2. ANNEX
Azure [documentation](https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#security) provides the full list of RBAC built-in roles to access to KeyVault. <br>
The Azure built-in roles for Key Vault data plane operations included in the **roleDefinitionBuiltIn** variable of the ARM template:

| Built-in role                            | Description                                                                                                                                                                                                                                                                                                                                                                 | ID                                   |
| ---------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------ |
| Key Vault Administrator                  | Perform all data plane operations on a key vault and all objects in it, including certificates, keys, and secrets. Cannot manage key vault resources or manage role assignments. Only works for key vaults that use the 'Azure role-based access control' permission model.                                                                                                 | 00482a5a-887f-4fb3-b363-3b7fe8e74483 |
| Key Vault Certificate User               | Read certificate contents. Only works for key vaults that use the 'Azure role-based access control' permission model.                                                                                                                                                                                                                                                       | db79e9a7-68ee-4b58-9aeb-b90e7c24fcba |
| Key Vault Certificates Officer           | Perform any action on the certificates of a key vault, except manage permissions. Only works for key vaults that use the 'Azure role-based access control' permission model.                                                                                                                                                                                                | a4417e6f-fecd-4de8-b567-7b0420556985 |
| Key Vault Crypto Officer                 | Perform any action on the keys of a key vault, except manage permissions. Only works for key vaults that use the 'Azure role-based access control' permission model.                                                                                                                                                                                                        | 14b46e9e-c2b7-41b4-b07b-48a6ebf60603 |
| Key Vault Crypto Service Encryption User | Read metadata of keys and perform wrap/unwrap operations. Only works for key vaults that use the 'Azure role-based access control' permission model.                                                                                                                                                                                                                        | e147488a-f6f5-4113-8e2d-b22465e65bf6 |
| Key Vault Crypto Service Release User    | Release keys. Only works for key vaults that use the 'Azure role-based access control' permission model.                                                                                                                                                                                                                                                                    | 08bbd89e-9f13-488c-ac41-acfcb10c90ab |
| Key Vault Crypto User                    | Perform cryptographic operations using keys. Only works for key vaults that use the 'Azure role-based access control' permission model.                                                                                                                                                                                                                                     | 12338af0-0e69-4776-bea7-57ae8d297424 |
| Key Vault Data Access Administrator      | Manage access to Azure Key Vault by adding or removing role assignments for the Key Vault Administrator, Key Vault Certificates Officer, Key Vault Crypto Officer, Key Vault Crypto Service Encryption User, Key Vault Crypto User, Key Vault Reader, Key Vault Secrets Officer, or Key Vault Secrets User roles. Includes an ABAC condition to constrain role assignments. | 8b54135c-b56d-4d72-a534-26097cfdc8d8 |
| Key Vault Reader                         | Read metadata of key vaults and its certificates, keys, and secrets. Cannot read sensitive values such as secret contents or key material. Only works for key vaults that use the 'Azure role-based access control' permission model.                                                                                                                                       | 21090545-7ca7-4776-b22c-e363652d74d2 |
| Key Vault Secrets Officer                | Perform any action on the secrets of a key vault, except manage permissions. Only works for key vaults that use the 'Azure role-based access control' permission model.                                                                                                                                                                                                     | b86a8fe4-44ce-4948-aee5-eccb2c155cd7 |
| Key Vault Secrets User                   | Read secret contents. Only works for key vaults that use the 'Azure role-based access control' permission model.                                                                                                                                                                                                                                                            | 4633458b-17de-408a-b874-0445c86b69e6 |

`Tags: Azure user-assigned managed identity, Azure keyvault, RBAC`  <br>
`date: 03-06-2024` <br>

<!--Image References-->

[1]: ./media/network-diagram.png "network diagram" 

<!--Link References-->

