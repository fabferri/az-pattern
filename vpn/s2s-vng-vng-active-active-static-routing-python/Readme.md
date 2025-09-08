<properties
pageTitle= 'Site-to-site VPN between two VPN Gateways deployed through Azure Python SDK'
description= "Site-to-site VPN between two VPN Gateways deployed through Azure Python SDK"
services="Azure VPN Gateway, Python"
documentationCenter="https://github.com/fabferri"
authors="fabferri"
editor="fabferri"/>

<tags
   ms.service="howto-Azure-examples"
   ms.devlang="na"
   ms.topic="article"
   ms.tgt_pltfrm="Azure"
   ms.workload="Azure VPN Gateway, "
   ms.date="08/09/2025"
   ms.review=""
   ms.author="fabferri" />

# Site-to-site VPN between two VPN Gateways deployed through Azure Python SDK

This article setup  site-to-site VPN tunnels between two Azure VPN Gateways operating in active-active mode. All resources are deployed using Azure Python SDK.
The network diagram is shown below:

[![1]][1]

The deployment creates:

- a **GatewaySubnet** 10.0.1.192/27 in **vnet1**,
- a **GatewaySubnet** 10.0.2.192/27 in **vnet2**.
- two local network gateways **localNetGw11**,**localNetGw12**, to define static routing to reach out the **vnet1**
- two local network gateways **localNetGw21**,**localNetGw22**, to define static routing to reach out the **vnet2**
- two connections **conn11** **conn12** in **gw1**,
- two connections **conn21** **conn22** in **gw2**,

[![2]][2]

### <a name="file list"></a>1. File list

| file                   | description                                               |
| ---------------------- | --------------------------------------------------------- |
| **create-gw1.py**      | python code to deploy the **vnet1**  with Azure VPN Gateway **gw1** in active-active mode with static routing |
| **create-gw2.py**      | python code to deploy the **vnet2** with Azure VPN Gateway **gw2** in active-active mode with static routing |
| **connections.py**     | python code to create local network Gateways and Connections     |
| **vms.py**             | python code to create Azure VMs in the **vnet1** and **vnet2**   |

Sequence of steps to make the deployment:

1. In the file **.env** fill out the variables **AZURE_SUBSCRIPTION_ID**, **SHARED_SERVICE_KEY**, **ADMINISTRATOR_USERNAME** and **ADMINISTRATOR_PASSWORD** with your correct values.
1. **create-gw1.py** and **create-gw2.py** are indipendent. You can run both in parallel in two terminals to speed up the deployments.
1. **connections.py** creates the VPN connections. Run the python code only after the creation of two VPN Gateways **gw1** **gw2**
1. In the script **vm.py** collect the administrator username of the VMs from **ADMINISTRATOR_USERNAME** value set in the file **.env** The code **vm.py** generates in the local folder the private (file: **id_rsa.pem**) and public (file: **id_rsa.pub**) RSA for the ubuntu VMs.

> [!NOTE]
>
> Run  **connections.py** only after creating VPN Gateway through **create-gw1.py** and **create-gw2.py**
>

<br>

`Tags: Azure VPN, Site-to-Site VPN Gateway, Python` <br>
`date: 08-09-2025` <br>

<!--Image References-->

[1]: ./media/network-diagram.png "network diagram"
[2]: ./media/s2s-tunnels.png "Site-to-Site IPsec tunnels"

<!--Link References-->
