<properties
pageTitle= 'Extending the GatewaySubnet address with VPN Gateway configured with site-to-site IPsec tunnels'
description= "Extending the GatewaySubnet address with VPN Gateway configured with site-to-site IPsec tunnels"
services="Azure VPN Gateway, extending GatewaySubnet"
documentationCenter="https://github.com/fabferri"
authors="fabferri"
editor="fabferri"/>

<tags
   ms.service="howto-Azure-examples"
   ms.devlang="na"
   ms.topic="article"
   ms.tgt_pltfrm="Azure"
   ms.workload="Azure VPN Gateway, "
   ms.date="22/08/2025"
   ms.review=""
   ms.author="fabferri" />

# Extending the GatewaySubnet address with VPN Gateway configured with site-to-site IPsec tunnels
This article setup and site-to-site VPN tunnels between two Azure VPN Gateways operating in active-active mode. All resources are deployed using Azure CLI commands in powershell.
The network diagram is shown below:

[![1]][1]

The deployment creates:

- a **GatewaySubnet** 10.0.1.224/27 in **vnet1**,
- a **GatewaySubnet** 10.0.2.224/27 in **vnet2**.

When the deployment of site-to-site IPsec tunnels is completed:

- the network 10.0.1.192/27 is added to the  GatewaySubnet of **vnet1**,
- the network 10.0.2.192/27 is added to the  GatewaySubnet of **vnet2**.

### <a name="file list"></a>1. File list

| file                    | description                                                                                |
| ----------------------- |:------------------------------------------------------------------------------------------ |
| **01-vng1.ps1**         | powershell script to deploy the **vnet1**  with Azure VPN Gateway **gw1** in active-active mode with BGP by Az CLI|
| **02-vng2.ps1**         | powershell script to deploy the **vnet10** alongside a VPN Gateway **gw2** in active-active mode with BGP by AZ CLI  |
| **03-connections.ps1**  | deployment of local network Gateways and Connections by AZ CLI    |
| **04-vms.ps1**          | deployment of Azure VMs in the subnets through AZ CLI             |

Sequence of steps to make the deployment:

1. In the powershell script **03-connections.ps1** set the value of the **$sharedSecret** = *'YOUR_SHARED_SECRET_FOR_THE_SITE_TO_SITE_VPN_TUNNEL'*.
1. In the script **04-vms.ps1** set properly the value of global variabiles **$global:username** = *'ADMINISTRATOR_USERNAME'* **$global:adminPassword** = *'ADMINISTRATOR_PASSWORD'* with credential of your VMs administrator.
1. Run in parallel **01-vng1.ps1** and **02-vng2.ps1**. Those deployments are independent.
1. Wait the completion of Azure VPN Gateways in vnet1 and vnet10. when both of them are completed, run **03-connections.ps1**. At the end the IPsec tunnels between the two Gateway should go UP. The status of IPsec tunnel can be displayed in Azure management portal; the status will be <ins>"Connected"</ins>.
1. Run the script **04-vms.ps1** to deploy the VMs in the subnets **subnet11** and **subnet21**.


<br>

## <a name="Local Network Gateways and Connections"></a>2. Local Network Gateways and Connections to establish the two IPsec tunnels

The site-to-site tunnels details are shown in the diagram:

[![2]][2]


## <a name="adding a new address to the GatwaySubnet"></a>3. Adding a new IP address prefix to the GatewaySubnet in vnet1

The network **10.0.1.192/27** is added to the **GatewaySubnet** of the **vnet1**:

The feature of subnet address extension is in preview and requires activation of Feature Flag (FF):

```azcli
az feature register --namespace Microsoft.Network --name AllowMultipleAddressPrefixesOnSubnet
az feature register --namespace Microsoft.Network --name AllowDeletionOfIpPrefixFromSubnet
```

The command returns a json output with **"state": "Registed"**
To check the status of feature flag:

```azurecli
az feature show --namespace Microsoft.Network --name AllowMultipleAddressPrefixesOnSubnet
az feature show --namespace Microsoft.Network --name AllowDeletionOfIpPrefixFromSubnet
```

update the existing GatewaySubnet with the new prefix:

```azurecli
az network vnet subnet update `
    --name GatewaySubnet `
    --vnet-name $vnet1Name `
    --resource-group $rg `
    --address-prefixes 10.0.1.224/27 10.0.1.192/27
```

```azurecli
az network vnet subnet show `
    --name GatewaySubnet `
    --vnet-name $vnet1Name `
    --resource-group $rg 
```

The command shows the following change:
{
  "addressPrefixes": [
    "10.0.1.224/27",
    "10.0.1.192/27"
  ],
  "delegations": [],
  "etag": "W/\"c4183cf1-b60e-45b0-b0c5-adbc407cf440\"",
  "id": "/subscriptions/XXXXXXXX-YYYY-ZZZZ-XXX-YYYYYYYYYYYY/resourceGroups/test-GatewaySubnet-extension/providers/Microsoft.Network/virtualNetworks/vnet1/subnets/GatewaySubnet",
  "ipConfigurations": [
    {
      "id": "/subscriptions/XXXXXXXX-YYYY-ZZZZ-XXX-YYYYYYYYYYYY/resourceGroups/TEST-GATEWAYSUBNET-EXTENSION/providers/Microsoft.Network/virtualNetworkGateways/GW1/ipConfigurations/VNETGATEWAYCONFIG0",
      "resourceGroup": "TEST-GATEWAYSUBNET-EXTENSION"
    },
    {
      "id": "/subscriptions/XXXXXXXX-YYYY-ZZZZ-XXX-YYYYYYYYYYYY/resourceGroups/TEST-GATEWAYSUBNET-EXTENSION/providers/Microsoft.Network/virtualNetworkGateways/GW1/ipConfigurations/VNETGATEWAYCONFIG1",
      "resourceGroup": "TEST-GATEWAYSUBNET-EXTENSION"
    }
  ],
  "name": "GatewaySubnet",
  "privateEndpointNetworkPolicies": "Disabled",
  "privateLinkServiceNetworkPolicies": "Enabled",
  "provisioningState": "Succeeded",
  "resourceGroup": "test-GatewaySubnet-extension",
  "type": "Microsoft.Network/virtualNetworks/subnets"
}


Adding the new address 10.0.1.192/27 to the Gateway subnet does not produce a distruption in site-to-site tunnels.

Removing the 10.0.1.192/27 from the Gateway subnet:

```azcli
az network vnet subnet update `
    --name GatewaySubnet `
    --vnet-name $vnet1Name `
    --resource-group $rg `
    --address-prefixes 10.0.1.224/27
```

Checking out the prefix 10.0.1.192/27 is not associated anymore to the GatewaySubnet in vnet1:

```azurecli
az network vnet subnet show `
    --name GatewaySubnet `
    --vnet-name $vnet1Name `
    --resource-group $rg 
```

The command shows the address prefix in the GatewaySubnet is only **"10.0.1.224/27"** :
{
  "addressPrefix": "10.0.1.224/27",
  "delegations": [],
  "etag": "W/\"09882659-f4fc-44a9-8acf-654372a4f275\"",
  "id": "/subscriptions/XXXXXXXX-YYYY-ZZZZ-XXX-YYYYYYYYYYYY/resourceGroups/test-GatewaySubnet-extension/providers/Microsoft.Network/virtualNetworks/vnet1/subnets/GatewaySubnet",
  "ipConfigurations": [
    {
      "id": "/subscriptions/XXXXXXXX-YYYY-ZZZZ-XXX-YYYYYYYYYYYY/resourceGroups/TEST-GATEWAYSUBNET-EXTENSION/providers/Microsoft.Network/virtualNetworkGateways/GW1/ipConfigurations/VNETGATEWAYCONFIG0",
      "resourceGroup": "TEST-GATEWAYSUBNET-EXTENSION"
    },
    {
      "id": "/subscriptions/XXXXXXXX-YYYY-ZZZZ-XXX-YYYYYYYYYYYY/resourceGroups/TEST-GATEWAYSUBNET-EXTENSION/providers/Microsoft.Network/virtualNetworkGateways/GW1/ipConfigurations/VNETGATEWAYCONFIG1",
      "resourceGroup": "TEST-GATEWAYSUBNET-EXTENSION"
    }
  ],
  "name": "GatewaySubnet",
  "privateEndpointNetworkPolicies": "Disabled",
  "privateLinkServiceNetworkPolicies": "Enabled",
  "provisioningState": "Succeeded",
  "resourceGroup": "test-GatewaySubnet-extension",
  "type": "Microsoft.Network/virtualNetworks/subnets"
}
 
`Tags: Azure VPN, Site-to-Site VPN, Gatewaysubnet` <br>
`date: 18-08-2025` <br>

<!--Image References-->

[1]: ./media/network-diagram.png "network diagram"
[2]: ./media/s2s-tunnels.png "Site-to-Site IPsec tunnels"

<!--Link References-->
