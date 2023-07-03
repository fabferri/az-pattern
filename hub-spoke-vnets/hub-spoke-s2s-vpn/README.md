<properties
pageTitle= 'Hub-spoke vnets with Azure Bastion in one hub vnet'
description= "Hub-spoke vnets with Azure Bastion in one hub vnet"
documentationcenter: na
services=""
documentationCenter="github"
authors="fabferri"
manager=""
editor=""/>

<tags
   ms.service="howto-Azure-examples"
   ms.devlang="na"
   ms.topic="article"
   ms.tgt_pltfrm="na"
   ms.workload="Azure vnet peering, Azure Bastion"
   ms.date="18/07/2022"
   ms.review=""
   ms.author="fabferri" />

# Hub-spoke vnets with Azure Bastion in one hub vnet
The article describes a scenario with hub-spoke vnets in peering, with Azure Bastion deployed only in one hub vnet. The network diagram is reported below:

[![1]][1]

The configuration aims to use Azure Bastion to manage all the VMs in the local hub-spoke vnets, as well as in the remote hub-spoke vnets.

- the Azure Bastion has to be deployed with **Standard** SKU;

- the properties of Azure Bastion are configured as:<br>
   "disableCopyPaste": false,<br>
   "enableFileCopy": true,<br>
   **"enableIpConnect": true,**<br>
   "enableShareableLink": false,<br>
   "enableTunneling": true, <br>
The property **enableIpConnect** is required to connect via Bastion to the VMs via private IP address.  

- Azure Bastion can reach out the remote spoke3 and spoke4 across the site-to-site VPN between VPN gtw1 and VPN Gtw2. 

- the vnet peering betwen hub2-spoke3 and hub2-spoke4 has to correctly assigned:
   - vnet peering property in spoke3 is set to "Use the remote virtual network's gateway"
   - vnet peering property in spoke4 is set to "Use the remote virtual network's gateway" 
   - vnet peering in hub2 is set to "Use this virtual network's gateway"


Below the property of the vnet peering in hub2 and spoke3 vnets:

[![2]][2]

<br>

[![3]][3]

Option in Azure Bastion to connect to the vmspoke3 via IP:

[![4]][4]

## <a name="list of files"></a>2. Files

| File name                 | Description                                                                    |
| ------------------------- | ------------------------------------------------------------------------------ |
| **init.json**             | define the value of input variables required for the full deployment           |
| **01-vnets.json**         | ARM template to deploy spoke vnets, hub vnets,Azure firewalls, Azure bastions  |
| **01-vnets.ps1**          | powershell script to run **01-vnets.json**                                     |
| **02-vpn.json**           | ARM template to deploy VPN Gateways in hub1 and hub2 and create the S2S VPN    |
| **02-vpn.ps1**            | powershell script to run **02-vpn.json**                                       |
| **03-vnets-peering.json** | ARM template to change the vnet peering properties between hub-spoke vnets     |
| **03-vnets-peering.ps1**  | powershell to script to run ****03-vnets-peering.json****                      | 


To run the project, follow the steps in sequence:
1. change/modify the value of input variables in the file **init.json**
2. run the powershell script **01-vnets.ps1**; at the end of execution the two hub-spoke will be created, with the VMs
3. run the powershell script **02-vpn.ps1**; at the end the IPsec tunnels between VPN gtw1 adn VPN gtw2 will be created
4. run the powershell script **vnet-peering.ps1**; the properties of vnet peering hub-spoke are changed: 
   - The vnet peering in the spokes will have the attribute "Use the remote virtual network's gateway" enabled
   - The vnet peering in the hubs will have the attribute "Use this virtual network's gateway" enabled 

The meaning of input variables in **init.json** are shown below:
```json
{
    "subscriptionName": "NAME_OF_AZURE_SUBSCRIPTION",
    "ResourceGroupName": "NAME_OF_RESOURCE_GROUP",
    "locationhub1": "AZURE_LOCATION_hub1_VNET",
    "locationspoke1": "AZURE_LOCATION_spoke1_VNET",
    "locationspoke2": "AZURE_LOCATION_spoke2_VNET",
    "locationhub2": "AZURE_LOCATION_hub2_VNET",
    "locationspoke3": "AZURE_LOCATION_spoke3_VNET",
    "locationspoke4": "AZURE_LOCATION_spoke4_VNET",
    "locationvnet1": "AZURE_LOCATION_vnet1",
    "adminUsername": "ADMINISTRATOR_USERNAME",
    "authenticationType": "password",
    "adminPasswordOrKey": "ADMINISTRATOR_PASSWORD",
    "mngIP": "PUBLIC_IP_ADDRESS_TO_FILTER_SSH_ACCESS_TO_VMS - it can be empty string, if you do not want to filter access!"
}
```
**authenticationType**: it can take two options: 
- **"password"** to authenticate to the VMs through the password
- **"sshPublicKey"** to autheticate to the VMs through RSA key


`Tags: hub-spoke vnets, azure Bastion` <br>
`date: 21-06-22`

<!--Image References-->

[1]: ./media/network-diagram.png "network diagram"
[2]: ./media/vnet-peering1.png "vnet peering properties in hub2"
[3]: ./media/vnet-peering2.png "vnet peering properties in spoke3"
[4]: ./media/bastion.png "from Bastion connect to the VM via IP"

<!--Link References-->

