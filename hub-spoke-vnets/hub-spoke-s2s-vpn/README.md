<properties
pageTitle= 'Hub-spoke vnets with S2S tunnels between the hubs'
description= "Hub-spoke vnets with S2S tunnels between the hubs"
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

# Hub-spoke vnets with site-to-site VPN tunnels between the hubs
The article describes a scenario with hub-spoke vnets in peering. The hub vnets are connected with S2S VPN tunnels through the VPN Gateways.<br>. The network diagram is reported below:

[![1]][1]


- The vnet peering betwen hub2-spoke3 and hub2-spoke4 are configured:
   - in spoke3, the vnet peering property is set to **"Use the remote virtual network's gateway"**
   - in spoke4, vnet peering property is set to **"Use the remote virtual network's gateway"** 
   - in hub2 vnet peering is set to **"Use this virtual network's gateway"**
- A single Azure Bastion is used to manage all the VMs.  Azure Bastion can reach out the remote spoke3 and spoke4 across the site-to-site VPN between VPN gtw1 and VPN Gtw2. The Azure Bastion has to be deployed with **Standard** SKU.
- all the VMs, in spokes and in the hubs, can communicate (there is no need of ip forwarder)
- the configuration does not use UDRs

Below the property of the vnet peering in hub2 and spoke3 vnets:

[![2]][2]

<br>

[![3]][3]

Option in Azure Bastion to connect to the vmspoke3 via IP:

[![4]][4]

<br>

Site-to-site VPN between the two Azure VPN Gateways:

[![5]][5]

## <a name="list of files"></a>2. Files

| File name                 | Description                                                                    |
| ------------------------- | ------------------------------------------------------------------------------ |
| **init.json**             | define the value of input variables required for the full deployment           |
| **01-vnets.json**         | ARM template to deploy spoke vnets, hub vnets, Azure Bastion, Azure VMS        |
| **01-vnets.ps1**          | powershell script to run **01-vnets.json**                                     |
| **02-vpn.json**           | ARM template to deploy VPN Gateways in hub1 and hub2 and create the S2S VPN    |
| **02-vpn.ps1**            | powershell script to run **02-vpn.json**                                       |
| **03-vnets-peering.json** | ARM template to change the vnet peering properties between hub-spoke vnets     |
| **03-vnets-peering.ps1**  | powershell to script to run ****03-vnets-peering.json****                      | 


To run the project, follow the steps in sequence:
1. change/modify the value of input variables in the file **init.json**
2. run the powershell script **01-vnets.ps1**; at the end of execution the two hub-spoke will be created, with the Azure VMs
3. run the powershell script **02-vpn.ps1**; at the end the site-to-site IPsec tunnels between VPN gtw1 and VPN gtw2 will be created
4. run the powershell script **vnet-peering.ps1**; the properties of vnet peering hub-spoke are changed: 
   - The vnet peering in the spokes will have the attribute **"Use the remote virtual network's gateway"** <ins>enabled</ins>
   - The vnet peering in the hubs will have the attribute **"Use this virtual network's gateway"** <ins>enabled</ins> 

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
    "adminPasswordOrKey": "ADMINISTRATOR_PASSWORD"
}
```
**authenticationType**: it can take two options: 
- **"password"** to authenticate to the VMs through the password
- **"sshPublicKey"** to autheticate to the VMs through RSA key


`Tags: hub-spoke vnets, azure Bastion` <br>
`date: 21-06-22` <br>
`date: 03-07-23` <br>

<!--Image References-->

[1]: ./media/network-diagram.png "network diagram"
[2]: ./media/vnet-peering1.png "vnet peering properties in hub2"
[3]: ./media/vnet-peering2.png "vnet peering properties in spoke3"
[4]: ./media/bastion.png "from Bastion connect to the VM via IP"
[5]: ./media/s2s-vpn.png "site-to-site VPN"

<!--Link References-->

