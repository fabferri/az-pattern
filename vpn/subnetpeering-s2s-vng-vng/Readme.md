<properties
pageTitle= 'Peered subnets deployed via Azure CLI and site-to-site IPsec tunnel between Azure VPN Gateways'
description= "Peered subnets deployed via Azure CLI and site-to-site IPsec tunnel between Azure VPN Gateways"
services="Azure VPN Gateway, subnet peering"
documentationCenter="https://github.com/fabferri"
authors="fabferri"
editor="fabferri"/>

<tags
   ms.service="howto-Azure-examples"
   ms.devlang="na"
   ms.topic="article"
   ms.tgt_pltfrm="Azure"
   ms.workload="Azure VPN Gateway, vnet peering"
   ms.date="28/11/2024"
   ms.review=""
   ms.author="fabferri" />

# Peered subnets deployed via Azure CLI and site-to-site IPsec tunnel between Azure VPN Gateways
This article guides you through configuring site-to-site IPsec tunnels between two Azure VPN Gateways operating in active-active mode, with peered subnets. All resources are deployed using Azure CLI.
The network diagram is shown below:

[![1]][1]

The subnet peering configuration aims to advertise through IPsec tunnels the subnets **subnet23** and **subnet24** in **vnet2** to the remote site **vnet10**. <br>
Subnet peering between **vnet1** and **vnet2** is deployed through the following AZ CLI commands:

```console
az network vnet peering create --name $peeringNamevnet1tovnet2 `
    --resource-group $rg --vnet-name $vnet1Name --remote-vnet $vnet2Name `
    --allow-forwarded-traffic true `
    --allow-gateway-transit true `
    --use-remote-gateways false `
    --allow-vnet-access true `
    --peer-complete-vnet false `
    --local-subnet-names $vnet1Subnet1Name $vnet1GatewaySubnetName `
    --remote-subnet-names $vnet2Subnet3Name $vnet2Subnet4Name

az network vnet peering create --name $peeringNamevnet2tovnet1 `
    --resource-group $rg --vnet-name $vnet2Name --remote-vnet $vnet1Name `
    --allow-forwarded-traffic true `
    --allow-gateway-transit false `
    --use-remote-gateways true `
    --allow-vnet-access true  `
    --peer-complete-vnet false `
    --local-subnet-names $vnet2Subnet3Name $vnet2Subnet4Name `
    --remote-subnet-names $vnet1Subnet1Name $vnet1GatewaySubnetName
```

`--allow-gateway-transit true`: the "allow gateway transit" is required to advertise the subnets in peering to the remote site **vnet10**
`--local-subnet-names $vnet1Subnet1Name $vnet1GatewaySubnetName`: GatewaySubnet is required in the subnet peering if you want to advertise the networks of subnet in peering to the remote site **vnet10**
`--use-remote-gateways true`: it is required to allow to the subnets in peering in vnet2 to be advertised to the remote site **vnet10**



### <a name="file list"></a>1. File list

| file                    | description                                                                                |
| ----------------------- |:------------------------------------------------------------------------------------------ |
| **01-vng1.ps1**         | Deployment of **vnet1** and **vnet2** with Azure VPN Gateway in active-active mode with BGP by Az CLI|
| **02-vng2.ps1**         | Provisioning **vnet10** alongside a VPN Gateway in active-active mode with BGP by AZ CLI   |
| **03-connections.ps1**  | deployment of local network Gateways and Connections by AZ CLI                             |
| **04-vms.ps1**          | deployment of Azure VMs in the subnets through AZ CLI                                      |
| **05-peering.ps1**      | subnet peering between **subnet11**, **GatewaySubnet** in **vnet1** and **subnet23**, **subnet24** in **vnet2**  by AZ CLI |

Sequence of steps to make the deployment:

1. Run in parallel **01-vng1.ps1** and **02-vng2.ps1**. Those deployments are independent.
1. In the script **03-connections.ps1** set the value of the **$sharedSecret** = *'YOUR_SHARED_SECRET_FOR_THE_SITE_TO_SITE_VPN_TUNNEL'*. Wait the completion of Azure VPN Gateways in vnet1 and vnet10. when both of them are completed, run **03-connections.ps1**. At the end the IPsec tunnels between the two Gateway should go UP. The status of IPsec tunnel can be displayed in Azure management portal; the status will be "Connected".
1. In the script **04-vms.ps1** set properly the value of global variabiles **$global:username** = *'ADMINISTRATOR_USERNAME'* **$global:adminPassword** = *'ADMINISTRATOR_PASSWORD'* with credential of your VMs administrator. Run the script **04-vms.ps1** to deploy the VMs in the subnets.
1. Run the script **05-peering.ps1** to create the subnet peering

<br>

## <a name="effective route tables"></a>2. Local Network Gateways and Connections to establish the two IPsec tunnels

The site-to-site tunnels details are shown in the diagram:

[![2]][2]


## <a name="effective route tables"></a>3. Effective route tables in Azure VMs

Effective route table in **vm11-nic**:

```console
az network nic show-effective-route-table `
  --name vm11-nic `
  --resource-group $rg -o table

Source                 State    Address Prefix    Next Hop Type          Next Hop IP
---------------------  -------  ----------------  ---------------------  ---------------------
Default                Active   10.0.1.0/24       VnetLocal
Default                Active   10.0.2.64/27      VNetPeering
Default                Active   10.0.2.96/27      VNetPeering
VirtualNetworkGateway  Active   10.0.10.197/32    VirtualNetworkGateway  10.0.1.196 10.0.1.197
VirtualNetworkGateway  Active   10.0.10.196/32    VirtualNetworkGateway  10.0.1.196 10.0.1.197
VirtualNetworkGateway  Active   10.0.10.0/24      VirtualNetworkGateway  10.0.1.196 10.0.1.197
Default                Active   0.0.0.0/0         Internet
```


```console
az network nic show-effective-route-table `
  --name vm21-nic `
  --resource-group $rg -o table

Source                 State    Address Prefix    Next Hop Type          Next Hop IP
---------------------  -------  ----------------  ---------------------  ---------------------
Default                Active   10.0.2.0/24       VnetLocal
Default                Active   10.0.1.0/27       VNetPeering
Default                Active   10.0.1.192/26     VNetPeering
VirtualNetworkGateway  Active   10.0.10.197/32    VirtualNetworkGateway  10.0.1.196 10.0.1.197
VirtualNetworkGateway  Active   10.0.10.196/32    VirtualNetworkGateway  10.0.1.196 10.0.1.197
VirtualNetworkGateway  Active   10.0.10.0/24      VirtualNetworkGateway  10.0.1.196 10.0.1.197
Default                Active   0.0.0.0/0         Internet
```

The routing table of **vm21** shows the following address prefixes:

- `10.0.2.0/24`: it is the vnet address space of vnet2
- `10.0.1.0/27`: it is network assigned to **subnet11** in **vnet1**
- `10.0.1.192/26`: it is the GatewaySubnet in **vnet1**
- `10.0.1.197/32`, `10.0.1.196/32`: IP addresses of the **gw1**
- `10.0.10.0/24`: it is the address space of the remote **vnet10**

**vm21** can't reach out the **vm11** neighter **vm101**

```console
az network nic show-effective-route-table `
  --name vm23-nic `
  --resource-group $rg -o table

Source                 State    Address Prefix    Next Hop Type          Next Hop IP
---------------------  -------  ----------------  ---------------------  ---------------------
Default                Active   10.0.2.0/24       VnetLocal
Default                Active   10.0.1.0/27       VNetPeering
Default                Active   10.0.1.192/26     VNetPeering
VirtualNetworkGateway  Active   10.0.10.197/32    VirtualNetworkGateway  10.0.1.196 10.0.1.197
VirtualNetworkGateway  Active   10.0.10.196/32    VirtualNetworkGateway  10.0.1.196 10.0.1.197
VirtualNetworkGateway  Active   10.0.10.0/24      VirtualNetworkGateway  10.0.1.196 10.0.1.197
Default                Active   0.0.0.0/0         Internet
```

```console
az network nic show-effective-route-table `
  --name vm24-nic `
  --resource-group $rg -o table

Source                 State    Address Prefix    Next Hop Type          Next Hop IP
---------------------  -------  ----------------  ---------------------  ---------------------
Default                Active   10.0.2.0/24       VnetLocal
Default                Active   10.0.1.0/27       VNetPeering
Default                Active   10.0.1.192/26     VNetPeering
VirtualNetworkGateway  Active   10.0.10.197/32    VirtualNetworkGateway  10.0.1.196 10.0.1.197
VirtualNetworkGateway  Active   10.0.10.196/32    VirtualNetworkGateway  10.0.1.196 10.0.1.197
VirtualNetworkGateway  Active   10.0.10.0/24      VirtualNetworkGateway  10.0.1.196 10.0.1.197
Default                Active   0.0.0.0/0         Internet
```

The routing table of **vm24** shows the following address prefixes:

- `10.0.2.0/24`: it is the vnet address space of vnet2
- `10.0.1.0/27`: it is network assigned to subnet11 in vnet1
- `10.0.1.192/26`: it is the GatewaySubnet in vnet1
- `10.0.1.197/32`, `10.0.1.196/32`: IP addresses of the gw1
- `10.0.10.0/24`: it is the address space of the remote vnet10


```console
az network nic show-effective-route-table `
  --name vm101-nic `
  --resource-group $rg -o table

Source                 State    Address Prefix    Next Hop Type          Next Hop IP
---------------------  -------  ----------------  ---------------------  -----------------------
Default                Active   10.0.10.0/24      VnetLocal
VirtualNetworkGateway  Active   10.0.2.64/27      VirtualNetworkGateway  10.0.10.196 10.0.10.197
VirtualNetworkGateway  Active   10.0.1.197/32     VirtualNetworkGateway  10.0.10.196 10.0.10.197
VirtualNetworkGateway  Active   10.0.1.0/24       VirtualNetworkGateway  10.0.10.196 10.0.10.197
VirtualNetworkGateway  Active   10.0.1.196/32     VirtualNetworkGateway  10.0.10.196 10.0.10.197
VirtualNetworkGateway  Active   10.0.2.96/27      VirtualNetworkGateway  10.0.10.196 10.0.10.197
Default                Active   0.0.0.0/0         Internet
```

The routing table of **vm101** shows the following address prefixes:
- `10.0.10.0/24`: it is the address space assigned to the vnet10
- `10.0.2.64/27`: it is the IP network assigned to **vnet2subnet3**
- `10.0.2.96/27`: it is the IP network assigned to **vnet2subnet4**
- `10.0.1.196/32`, `10.0.1.197/32`: The IP addresses assigned to **gw1**

The routing table of the **vm101** shows evidence that only the subnets in peering `10.0.2.64/27` `10.0.2.96/27` and are advertised through the S2S tunnels to the vnet10.
 
`Tags: Azure VPN, Site-to-Site VPN, subnet peering` <br>
`date: 18-08-2025` <br>

<!--Image References-->

[1]: ./media/network-diagram.png "network diagram"
[2]: ./media/s2s-tunnels.png "Site-to-Site IPsec tunnels"

<!--Link References-->
