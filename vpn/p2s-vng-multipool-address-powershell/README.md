<properties
pageTitle= 'Multipool address for P2S connection in Azure VPN Gateway'
description= "Multipool address for P2S connection in Azure VPN Gateway"
documentationcenter= "https://github.com/fabferri"
services="VPN Gateway"
authors="fabferri"
editor="fabferri"/>

<tags
   ms.service="configuration-Example-Azure"
   ms.devlang="powershell"
   ms.topic="article"
   ms.tgt_pltfrm="Azure"
   ms.workload="VPN Gateway"
   ms.date="18/03/2025"
   ms.author="fabferri" />

# Multipool address for P2S connection in Azure VPN Gateway by powershell
This post contains a powershell script to configure multipool address for Point-to-Site (P2S) connections in Azure VPN  gateway. <br>
As authetication methods of P2S connections is used only digital certificate.
The network diagram is shown below:
[![1]][1]

### <a name="generate digital certificates"></a>1. Powershell script to generate digical certificates 
The powershell script **create-root-and-clients-certificates.ps1** can be run in windows host or VM to generate a root certificate and client certificates signed by root certificate.<br>
**All the generated client certificates are signed with the same root certificate.** <br>

The script generates three folders with different client certificates, each with a different Common Name (CN):

The folder **_folder1_** contains the client certificate with CN=cert@marketing.contoso.com

[![2]][2]

The folder **_folder2_** contains the client certificate with CN=cert@sale.contoso.com

[![3]][3]


The folder **_folder3_** contains the client certificate with CN=cert@engineering.contoso.com

[![4]][4]


For this specific case, we will consider only the two client certificates with Common Names **cert@sale.contoso.com** and **cert@engineering.contoso.com**

### <a name="P2S multipool address"></a>2. Powershell script to configure Point-to-Site with multipool address
The **gw.ps1** script creates an Azure VNet with two subnets and a VPN Gateway with P2S configuration and multipool address.
In the VPN Gateway, the P2S connections are configured with:
- tunnel type **IKE**
- authetication based on **digital certificates**

[![5]][5]

The configuration creates two gateway policy groups:
- **policyGroup1**: This policy group is responsible for authorizing connections using digital certificates that specify **sale.contoso.com** in the Common Name (CN) field.
- **policyGroup2**: This policy group is responsible for authorizing connections using digital certificates that specify **engineering.contoso.com** in the Common Name (CN) field.

Two gateway policy groups are created as described in the table:

| policy group name | Default Policy | Priority | Group Name  | Authentication Type | group configuration value|
|-------------------|----------------|----------|-------------|---------------------|--------------------------|
|policyGroup1       | true           | 0        | Sale        | CertificateGroupId  | sale.contoso.com         |
|policyGroup2       | false          | 10       | Engineering | CertificateGroupId  | engineering.contoso.com  |

The VPN configuration defines two distinct address pools, each linked to a specific policy group:
| vpn configuration name  | Address pool   |
|-------------------------|----------------|
|**config1**              | 192.168.1.0/24 |
|**config2**              | 192.168.2.0/24 |

The VPN connection configuration **config1** is associated with the Gateway policy **Group1** <br>
The VPN connection configuration **config2** is associated with the Gateway policy **Group2** <br>

> [!NOTE]
>
> The **gw.ps1** requires the mandatory specification of public certificate data of the root certificate specified in the variable **$samplePublicCertData**. Without the root certificate data, the deployment of the VPN Gateway will fail. <br>
> Before running the **gw.ps1** collect the public part of root certificate (P2Sroot.cer) and copy it in the variable **$samplePublicCertData**.

### <a name="powershell script"></a>3. List of steps in sequence to connect in P2S
The steps to connect P2S clients to the VPN Gateway are as follows:
- On a Windows host or VM, run the script **create-root-and-clients-certificates.ps1** to generate various digital certificates for clients, signed by the root certificate. Note that both the root certificates and client certificates will be stored on that host. The client certificates and public root certificate need to be exported and copied to the clients' laptops, desktops, or VMs.
- Copy the two P2S client digital certificates (Sales, Engineering) and the root certificate **P2SRootCert.cert** into two different P2S clients (on separate laptops or VMs). Import the digital certificates into the laptops/VMs.
- In the Azure management portal, select the Azure VPN Gateway P2S configuration and download the P2S client profile. Copy the client profile to the VPN clients desktops/laptops.
- Import the user profile (XML file) into the Azure VPN clients.
- Use the user profile to connect to the Azure VPN Gateway.


`Tag: Point-to-Site VPN, multipool` <br>
`date: 18-03-2025`

<!--Image References-->

[1]: ./media/network-diagram.png "network diagram"
[2]: ./media/folder1.png "list of files in the folder1"
[3]: ./media/folder2.png "list of files in the folder2"
[4]: ./media/folder3.png "list of files in the folder3"
[5]: ./media/p2s-config.png "P2S configuration in the VPN Gateway"

<!--Link References-->

