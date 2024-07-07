<properties
pageTitle= 'Assign a user-assigned managed identity to an existing VM'
description= "Assign a user-assigned managed identity to an existing VM"
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
   ms.date="11/06/2024"
   ms.author="fabferri" />

# Assign a user-assigned managed identity to an existing VM
**Managed Service Identity** (**MSI**) provides an identity for applications to use when connecting to resources that support Azure Active Directory (Azure AD) authentication.
Applications may use the managed identity to obtain Azure AD tokens. You can use managed identities to authenticate to any resource that supports Azure AD authentication. <br>
This article discusses how to use a user-assigned managed identity with role of Contributor assigned to a Windows VM. <br> 

The powershell script
- create a vnet
- create the NSG with two security rules (one to accept inbound RDP traffic and one to accept SSH)
- create a public IP
- create a NIC
- start the Windows VM
- use custome script extension to run a powershell script (**install-az-powershell.ps1**) to install the azure powershell in the Azure VM
- create a user-managed identity
- associated the roles to the managed user identity; the role scope to subscription or resource group
- assign the user-assigned managed identity to the Windows VM

Based on the value assigned to the variable **$case**, the powershell assigns the user-assigned managed identity three different roles:
- case 1: **Reader** role with scope set to **Subscription** 
- case 2: **Contributor** role with scope set to **Resource Group** 
- case 3: **Contributor** role with scope set to **Resource Group** and **Reader** role with scope set to **Subscription**

Below the three cases with role assigned to the user-assigned managed identity:

## <a name="Reader role"></a>Case 1: Reader role with Subscription scope 

[![1]][1]

[![2]][2]

## <a name="Contributor role"></a>Case 2: Contributor role with Resource Group scope 

[![3]][3]

[![4]][4]

## <a name="Contributor role and Reader role"></a>Case 4: Contributor role with Resource Group scope and Reader role with subscription scope 

[![5]][5]

[![6]][6]

## <a name="contributor role"></a>Connect to the VM and login in powershell with user-assigned managed identity
Identify the clientId of the <ins>user assigned managed identity</ins>:
```powershell
$usrAssignedClientId= (Get-AzUserAssignedIdentity -ResourceGroupName $rgName -Name userAssignedIdentity-01).ClientId
$usrAssignedClientId
```
After the deployment, login in the Windows VM and run the following powershell commands:
```powershell
Connect-AzAccount -Identity -AccountId <usrAssignedClientId>
```
replace the `<usrAssignedClientId>` with numerical value.


`Tags: User-assigned managed identity` <br>
`date: 07-07-2024` <br>

<!--Image References-->
[1]: ./media/reader-scope-subscription.png
[2]: ./media/managed-usr-identity-role-assigned-scope-subscription.png "reader role assigned to managed user identity: scope Subscription"
[3]: ./media/contributor-scope-resource-group.png
[4]: ./media/managed-usr-identity-role-assigned-scope-resourcegroup.png "contributor role assigned to managed user identity: scope Resource Group" 
[5]: ./media/contributor-and-reader.png
[6]: ./media/managed-usr-identity-more-roles.png "two roles assigned to managed user identity with different scope" 
<!--Link References-->

