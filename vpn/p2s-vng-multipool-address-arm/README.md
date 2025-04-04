<properties
pageTitle= 'Multipool address for P2S connection in Azure VPN Gateway by ARM template'
description= "Multipool address for P2S connection in Azure VPN Gateway  by ARM template"
documentationcenter= "https://github.com/fabferri"
services="VPN Gateway"
authors="fabferri"
editor="fabferri"/>

<tags
   ms.service="configuration-Example-Azure"
   ms.devlang="ARM template"
   ms.topic="article"
   ms.tgt_pltfrm="Azure"
   ms.workload="VPN Gateway"
   ms.date="03/04/2025"
   ms.author="fabferri" />

# Multipool address for P2S connection in Azure VPN Gateway by ARM template
This post provides ARM templates to configure a multipool address for Point-to-Site (P2S) connections in Azure VPN Gateway. The authentication method used for P2S connections is digital certificates only. Below is the network diagram:

[![1]][1]


### <a name="generate digital certificates"></a>1. File list
| File Name               | Description                                                          | 
|-------------------------|----------------------------------------------------------------------|
| **00_create-root-and-clients-certificates.ps1** | PowerShell script to generate the root certificate and client certificates on a Windows host/VM |
| **init.json**           | File containing the list of variables to set before running the deployment | 
| **01-gw.json**          | ARM template to create the Azure VPN Gateway with multiple pool addresses  | 
| **01-gw.ps1**           | Powershell script to run **01-gw.json**                              |
| **02-client-vnet.json** | ARM template to create the VNet for the client VM (different from the VPN Gateway VNet)|
| **02-client-vnet.ps1**  | PowerShell script to run  **02-client-vnet.json**                     |
| **03-vms.json**         | ARM template to deploy the Windows client VM and the workload VM in the VPN Gateway VNet|
| **03-vms.ps1**          | PowerShell script to run **03-vms.json**                             |
| **03-vms.ps1**          | Powershell script to run **03-vms.json**                             |
| **collect-multipool-info.ps1** | PowerShell script to fetch the multipool address, runnable after deploying **01-gw.json**  |

### <a name="generate digital certificates"></a>1. Powershell script to generate digital certificates 
The PowerShell script **create-root-and-clients-certificates.ps1** generates a root certificate and client certificates signed by the root certificate. This script can be run on a Windows host or VM. All generated client certificates are signed with the same root certificate.

The script creates three folders, each containing client certificates with different Common Names (CN):<br>

The script generates three folders with different client certificates, each with a different Common Name (CN):
- the folder **_folder1_** contains the client certificate with **CN=cert@marketing.contoso.com**
- the folder **_folder2_** contains the client certificate with **CN=cert@sale.contoso.com**
- the folder **_folder3_** contains the client certificate with **CN=cert@engineering.contoso.com**
<br>

For this specific case, we will consider only the client certificates with CNs ***cert@sale.contoso.com** and **cert@engineering.contoso.com**.


### <a name="deployment sequence"></a>2. Deployment sequence
The deployment requires few steps executed in sequence:
1. generate the digital certificates (root and clients) by **00_create-root-and-clients-certificates.ps1**. Without the root certificate data, the deployment of the VPN Gateway will fail.
[![2]][2]
1. copy the public data of the root certificate (P2SRoot.cer) in the variable **"vpnRootCertificatePublicKey"** of the file **init.json**. Do <ins>not</ins> include the header (-----BEGIN CERTIFICATE-----) and trailer ()
[![3]][3]-----END CERTIFICATE-----
1. Run **01-gw.ps1** to create VNet1 and the VPN Gateway. The ARM template 01-gw.json deploys the VPN Gateway with P2S configuration:
   - Tunnel type: IKE
   - Authentication: digital certificates
   - Multipool address configuration added to the VPN Gateway.
[![4]][4]
1. **02-client-vnet.ps1**  to create VNet2 for the Windows client VM.
1. **03-vms.ps1** to deploy the VM1 and WinClient VMs.
1. login to the WinClient VM and import the digital certificates (root and client) into the personal store. This can be done using the certificate snap-in or through PowerShell:
```powershell
# get the PKi module
Get-Command -Module PKI
# import a client certificate in Personal certificate store
Import-PfxCertificate –FilePath C:\cert3\certClient3.pfx Cert:\CurrentUser\My -Password (ConvertTo-SecureString -String "12345" -Force –AsPlainText)
```
1. Install the Azure VPN client on the WinClient VM
1. Download the VPN client profile (zip file) from the Azure management portal.
1. Import the user profile (**azurevpnconfig.xml**) into the Azure VPN client on the WinClient VM.
1. Connect to the Azure VPN Gateway using P2S.


### <a name="deployment sequence"></a>3. Multipool configuration
The multipool configuration creates two gateway policy groups:
- **policyGroup1**: Authorizes connections using digital certificates with **CN=engineering.contoso.com**.
- **policyGroup2**: Authorizes connections using digital certificates with **CN=sale.contoso.com**.

The table below describes the two gateway policy groups:

| policy group name | Default Policy | Priority | Group Name  | Authentication Type | group configuration value|
|-------------------|----------------|----------|-------------|---------------------|--------------------------|
| policyGroup1      | true           | 0        | Engineering | CertificateGroupId  | engineering.contoso.com  |
| policyGroup2      | false          | 10       | Sale        | CertificateGroupId  | sale.contoso.com         |

The VPN configuration defines two distinct address pools, each linked to a specific policy group:
| vpn configuration name  | Address pool   |
|-------------------------|----------------|
|**config1**              | 192.168.1.0/24 |
|**config2**              | 192.168.2.0/24 |

The VPN connection configuration **config1** is associated with the Gateway policy **Group1** <br>
The VPN connection configuration **config2** is associated with the Gateway policy **Group2** <br>

### <a name="Verification"></a>4. Verification of P2S connection
At deployment time a customer script extension in ARM template **vms.json** install automatically in **vm1** a nginx server. <br>
When the P2S tunnel is up, in Windows client you can open a web browse and access in HTTP to the web server installed in vm1.

`Tag: Point-to-Site VPN, multipool` <br>
`date: 03-04-2025`

<!--Image References-->

[1]: ./media/network-diagram.png "network diagram"
[2]: ./media/digital-certificates.png "create digital certificates"
[3]: ./media/public-data-root-certificate.png "public data root certificate"
[4]: ./media/p2s-config.png "point-to-site configuration"


<!--Link References-->
