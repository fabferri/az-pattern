<properties
pageTitle= 'Azure ARM template to create a Key Vault with list of secrets'
description= "Azure ARM template to create a Key Vault with list of secrets"
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
   ms.date="28/08/2023"
   ms.author="fabferri" />

# Azure ARM template to create a Key Vault with list of secrets
In the paramenter file **keyvault-params.json** 

```json
"objectId": {
      "value": "GEN-AZUREAD-OBJECTID"
    },
```

replace the the string **GEN-AZUREAD-OBJECTID** with the value of user ID in Azure Active Directory:

```powershell
$objectId = (Get-AzADUser -UserPrincipalName (Get-AzContext).Account).Id
write-host $objectId
```

`Tags: Azure Key Vault, secrets` <br>
`date: 28-08-23`


<!--Image References-->


<!--Link References-->

