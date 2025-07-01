<properties
pageTitle= 'Azure ARM templates to create site-to-site VPN with digital certificate authentication'
description= "Azure ARM templates to create site-to-site VPN with digital certificate authentication"
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
   ms.date="30/06/2025"
   ms.author="fabferri" />

# Azure ARM templates to create site-to-site VPN with digital certificate authentication
This post contains ARM templates and script to create site-to-site VPN between Azure VPN Gateways with digital certificate authetication. <br>
The network configuration is reported in the diagram:

[![1]][1]


Each Azure VPN Gateway is configured in active-active and BGP routing.
The configuration of VPN Gateway is reported in the diagram below:

[![2]][2]

### <a name="file list"></a>1. File list

| file              | description                                                                  |       
| ----------------- |:---------------------------------------------------------------------------- |
| **s2s-gen-cert.ps1**| powershell script to create root certificates and leaf certificates for **gw1** and **gw2** |
| **init.json**     | file with list of input variables                                            |
| **01-gws.json**   | ARM template to create two VNets with VPN Gateway, user managed identity and keyvault |
| **01-gws.ps1**    | powershell script to deploy the ARM template **01-gws.json**                 |
| **02-load-cert-in-keyvault.ps1** | powershell script to load the digital certificates in keyvault|
| **03-conns.json** | ARM template to create local networks gateway and VPN connections            |
| **03-conns.ps1**  | powershell script to deploy the ARM template **03-conns.json**               |




The meaning for variables in **init.json** file is shown below:
```json
{
    "subscriptionName": "SUBSCRIPTION_NAME",
    "rgName": "RESOURCE_GROUP_NAME",
    "location1": "AZURE_LOCATION_VNET1",
    "location2": "AZURE_LOCATION_VNET2",
    "adminUsername": "ADMINISTRATOR_USERNAME",
    "adminPassword": "ADMINISTRATOR_PASSWORD",
    "gateway1Name": "NAME_OF_THE_GW1_IN_VNET1",
    "gateway2Name": "NAME_OF_THE_GW2_IN_VNET1",
    "outboundCertificateFileNamePFX1": "FILENAME_OF OUTBOUND_CERTIFICATE_FOR_GW1",
    "outboundCertificatePasswordPFX1": "PASSWORD TO IMPORT THE OUTBOUND_CERTIFICATES_FOR_GW1",
    "inboundCertificateFileNameCER1": "ROOT_CERTIFICATE_FOR_GW1",
    "inboundCertificateSubjectName1" : "COMMON_NAME_OUTBOUND_CERTIFICATE_GW1",
    "outboundCertificateFileNamePFX2": "FILENAME_OF OUTBOUND_CERTIFICATE_FOR_GW2",
    "outboundCertificatePasswordPFX2":  "PASSWORD TO IMPORT THE OUTBOUND_CERTIFICATES_FOR_GW2",
    "inboundCertificateFileNameCER2": "ROOT_CERTIFICATE_FOR_GW2",
    "inboundCertificateSubjectName2" : "COMMON_NAME_OUTBOUND_CERTIFICATE_GW2"
}
```

> [!NOTE]
> 
> **The ARM templates require as mandatory Azure region with availability zone**. <br>
> The deployment uses different outbound certificates for the gw1 and gw2. <br>
>

### <a name="how to run"></a>2. How to deploy the project
List of steps in sequence:

1. customize the value of variables in the **init.json** file
1. In the **02-load-cert-in-keyvault.ps1** script, set the <ins>**$userToAccessToKeyvault**</ins> variable to specify the Azure user who requires access to the certificates stored in the KeyVault
1. Run the powershell script **s2s-gen-cert.ps1** to create the digital certificates. the script creates and export the digital certificates in the local folder ./certs/
1. Customize the value of variables in the **init.json** file
1. Run the script **01-gws.ps1** to generate: 
   - VNets, 
   - VPN Gateways **gw1** and **gw2** 
   - VMs
   - Keyvault
   - user identity to access to the keyvault
1. Run the **02-load-cert-in-keyvault.ps1** to load the leaf certificates in the keyvault
1. Run the **03-conns.ps1** to create the Local Network Gateways and Connections. In each Connection the authetication references the **Outbound Certificate Path**, **Inbound Certificate Subject**, and **Inbound Certificate Chain** 



### <a name="generate digital certificates"></a>3. Powershell script to generate digital certificates 

The script **s2s-gen-cert.ps1** creates the digital certificates. The script can run in Windows VM/host: 


[![3]][3]

In this example two self-signed root certificates  are created and used to sign the leaf certificates for the **gw1** and **gw2**. The digital certificates can be created by powershell script **s2s-gen-cert.ps1**

The digital certificates are exported in the local folder **./certs/**.

[![4]][4]

In S2S with digital certificate authentication, there are two type of certificates:
- the **outbound certificate** is used to verify connections  <ins>from Azure VPN Gateway to a remote site</ins>.
The certificate is stored in Azure Key Vault. You specify the outbound certificate path identifier in keyvault when you configure your site-to-site connection. You can create a certificate using a certificate authority of your choice, or you can create a self-signed root certificate.
- The **inbound certificate** is used to validate the connection coming <ins>from remote site to the VPN Gateway</ins>. 
The subject name value is used when you configure your site-to-site connection.


<br>

### <a name="import digital certificates in keyvault"></a>4. Powershell script to import the leaf certificates in keyvault 

The script **02-load-cert-in-keyvault.ps1** import the leaf certificates **s2s-client1** and **s2s-client2** in keyvault:

[![5]][5]

The diagram below illustrates how the **Outbound Certificate Path**, **Inbound Certificate Subject**, and **Inbound Certificate Chain** are configured on both **gw1** and **gw2**.

[![6]][6]

The values of **Outbound Certificate Path**, **Inbound Certificate Subject**, and **Inbound Certificate Chain** are specified in configuration of the Site-to-Site connections.


`Tag: Site-to-Site VPN, digital certificates` <br>
`date: 30-06-2025`

<!--Image References-->

[1]: ./media/network-diagram.png "network diagram"
[2]: ./media/network-details.png "VPN Local Network Gateway and Connections"
[3]: ./media/creation-certificates.png "generate root certificatesa and leaf certificates for the gw1 and gw2"
[4]: ./media/export-certificates.png "export of root certificatesa and leaf certificates for the gw1 and gw2 in local folder ./certs/"
[5]: ./media/store-certificates-in-keyvault.png "digital certificates for gw1 and gw2 stored in keyvault"
[6]: ./media/inbound-and-oubound-certificates.png "Outbound Certificate Path, Inbound Certificate Subject, and Inbound Certificate Chain** for gw1 and gw2"

<!--Link References-->
