<properties
pageTitle= 'Azure ARM template to create multiple Key Vaults in different resource groups'
description= "Azure ARM template to create multiple Key Vaults in different resource groups"
documentationcenter: na
services="networking"
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
   ms.date="28/07/2020"
   ms.author="fabferri" />

## Azure ARM template to create multiple Key Vaults in different resouce groups

The ARM template creates multiple resource groups and then deploys in each of them a Key Vault. Inside the Key Vault are stored three secrets (user password).

The commands to deploy an ARM template requires you to provide a resource group name to deploy to:

```powershell
New-AzResourceGroupDeployment [-Name <String>] -ResourceGroupName <String> -TemplateFile <String>
```
ARM templates required you to supply the name of the resource group you want to deploy to as part the deployment command. This restriction meant that the resource group always needed to exist before running your deployment.
The challenge to create resource group and then resources inside can be achieved by nested ARM templates. ARM Nested templates provides a way to call one template from an inline template inside the same file. When you use a nested template, you define the resource group in that template, and so this provides a way for resources to use the resource group just created.
In the example below we are going to deploy a Key Vault into the resource group we create:

```json
{
    "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#",
    "contentVersion": "1.0.0.0",
    "parameters": {
        "rgName": {
            "type": "string"
        },
        "location": {
            "type": "string"
        },
        "kvName": {
            "type": "string"
        },
        "tenantId": {
            "type": "string",
            "defaultValue": "[subscription().tenantId]"
        },
        "objectId": {
            "type": "string",
        }
    },
    "variables": {},
    "resources": [
        {
            "type": "Microsoft.Resources/resourceGroups",
            "apiVersion": "2019-10-01",
            "name": "[parameters('rgName')]",
            "location": "[parameters('location')]",
            "properties": {}
        },
        {
            "type": "Microsoft.Resources/deployments",
            "apiVersion": "2019-10-01",
            "name": "keyVaultDeployment",
            "resourceGroup": "[parameters('rgName')]",
            "dependsOn": [
                "[resourceId('Microsoft.Resources/resourceGroups', concat(parameters('rgName')))]"
            ],
            "properties": {
                "mode": "Incremental",
                "template": {
                    "$schema": "https://schema.management.azure.com/schemas/2015-01-01/deploymentTemplate.json#",
                    "contentVersion": "1.0.0.0",
                    "parameters": {},
                    "variables": {},
                    "resources": [
                        {
                            "type": "Microsoft.KeyVault/vaults",
                            "name": "[parameters('kvName')]",
                            "apiVersion": "2019-09-01",
                            "location": "[parameters('location')]",
                            "dependsOn": [],
                            "properties": {
                                "tenantId": "[parameters('tenantId')]",
                                "enabledForDeployment": false,
                                "enabledForDiskEncryption": false,
                                "enabledForTemplateDeployment": true,
                                "enableSoftDelete": false,
                                "accessPolicies": [
                                    {
                                        "tenantId": "[parameters('tenantId')]",
                                        "objectId": "[parameters('objectId')]",
                                        "permissions": {
                                            "keys": ["list"],
                                            "secrets": ["get","list","set","delete"]
                                        }
                                    }
                                ],
                                "sku": {
                                    "name": "Standard",
                                    "family": "A"
                                },
                                "networkAcls": {
                                    "value": {
                                        "defaultAction": "Allow",
                                        "bypass": "AzureServices"
                                    }
                                }
                            }
                        }
                    ]
                  }
            }
        }
    ]
}
```

The AM template can be deployed through the Azure powershell command:

```powershell
New-AzDeployment -Name <String> -TemplateFile <ARM-template> -Location <AzureRegion>
```

The powershell command **New-AzDeployment** doesn't require the reference of resource group and fit well with our purpose.
Below a graphical representation of ARM template deployment:

[![1]][1]

File
* **keyvault.ps1**: powershell script to deploy **keyvault.json**
* **keyvault.json**: ARM template to create resource groups, each a Key Vault and secrets

> **_Note_**
>
> Before running the powershell **keyvault.ps1**, set the right values of the variables:
>
> **$subscriptionName**: name of the Azure subscription
>
> **$objectId**: Specifies the object ID of a user, service principal or security group in the Azure Active Directory tenant for the vault. The object ID must be unique for the list of access policies. Get it by using Get-AzADUser or Get-AzADGroup or Get-AzADServicePrincipal cmdlets.
>
> **$location**: Azure location 
>



<!--Image References-->

[1]: ./media/network-diagram.png "network diagram"

<!--Link References-->

