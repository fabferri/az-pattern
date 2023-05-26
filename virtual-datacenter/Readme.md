<properties
pageTitle= 'Azure Virtual Datacenter'
description= "full deployment of an Azure Virtual Datacenter through ARM templates"
documentationcenter: na
services=""
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
   ms.date="07/02/2023"
   ms.author="fabferri" />

# Azure Virtual Datacenter deployment through ARM templates
This article presents a network configuration in hub-spoke topology enriched with cross-networking features. The final network diagram is shown below:

[![1]][1]


The environment can progressively build over the 9 steps, by execution in sequence through ARM templates. <br>
It starts with creation of all vnets and vnet peering. The hub vnet contains a private VM (without public IP) along with a Bastion host and NAT Gateway that enable external (public) connectivity. Then an Azure firewall is added in the hub with various policy rules to control the flow of traffic. <br> The first spoke hosts a web service (IIS) behind an App Gateway. <br>
The second spoke runs a VM Scale Set behind a Network Load Balancer. This spoke also includes a Private Endpoint for private and secure connectivity to Azure Storage service (PaaS). <br>
The third spoke is added in a different region and hosts a web service (IIS) behind an Application Gateway. The web service access to content stored in the Azure storage through private endpoint.
Azure Front Door provides the geo load balancing between the web servers in two different regions. <br>


IP address assignment:

[![2]][2]



## <a name="File list with sequence of steps"></a>1. File list with sequence of steps
The full deployment can be achieved running ARM templates in sequence. Here the diagram with the step sequence:

[![3]][3]

The table below describes the purpose of each step, with short description actions and outcome produced in each step.

|step      | file                   | description                                                               |       
|----------| ---------------------- |:------------------------------------------------------------------------- |
| step 0   | **init.json**          | the file **init.json** contains the list of variables used across all the steps. <br>Customize the value of variables with your value before running all the deployment|
| step 0   | **IISBuildHub.ps1**    | store the powershell script **IISBuildHub.ps1** in the web site folder named **scripts** (i.e. blob storage with public access or public github folder). The script is used to setup the IIS in hub vnet. <br> **Without this  script deployment of VMs in hub it will fail** |
| step 0   | **IISBuildS1.ps1**     | store the powershell script **IISBuildS1.ps1** in the web site folder named **scripts** (i.e. blob storage with public access or public github folder). The script is used to setup the IIS in spoke1 vnet. <br> **Without this  script deployment of VMs in spoke1 it will fail** |
| step 0   | **IISBuildS3.ps1**     | store the powershell script **IISBuildS3.ps1** in the web site folder named **scripts** (i.e. blob storage with public access or public github folder). The script is used to setup the IIS in spoke3 vnet. <br> **Without this  script deployment of VMs in spoke3 it will fail** |
| step 1   | **01-vnets-hub.json**  | ARM template to create all the vnets (hub, spoke1,spoke2,spoke3, on-prem)  and vnet peering|
| step 1   | **01-vnets-hub.ps1**   | powershell script to deploy the ARM template **01-vnets-hub.json**                         |
| step 2   | **02-azfw.json**       | ARM template to create azure firewall in the hub and firewall security policy              |
| step 2   | **02-azfw.ps1**        | powershell script to deploy the ARM template **02-azfw.json**                              |
| step 3   | **03-vpn.json.json**   | ARM template to create VPN Gateways in hub and onpremises vnet and establish sit-to-site VPN|
| step 3   | **03-vpn.json.ps1**    | powershell script to deploy the ARM template **03-vpn.json.json**                          |
| step 4   | **04-spoke2.json**     | ARM template to create all the vnets (hub, spoke1,spoke2,spoke3, on-prem)  and vnet peering|
| step 4   | **04-spoke2.ps1**      | powershell script to deploy the ARM template **04-spoke2.json**                            |
| step 5   | **05-spoke2-staticweb.json**  | ARM template to create all the vnets (hub, spoke1,spoke2,spoke3, on-prem)  and vnet peering|
| step 5   | **05-spoke2-staticweb.ps1**   | powershell script to deploy the ARM template **05-spoke2-staticweb.json**           |
| step 6   | **06-spoke1.json**     | ARM template to create all the vnets (hub, spoke1,spoke2,spoke3, on-prem)  and vnet peering|
| step 6   | **06-spoke1.ps1**      | powershell script to deploy the ARM template **06-spoke1.json**                            |
| step 7   | **07-spoke3.json**     | ARM template to create all the vnets (hub, spoke1,spoke2,spoke3, on-prem)  and vnet peering|
| step 7   | **07-spoke3.ps1**      | powershell script to deploy the ARM template **07-spoke3.json**                            |
| step 8   | **08-spoke3-staticweb.json**  | ARM template to create all the vnets (hub, spoke1,spoke2,spoke3, on-prem)  and vnet peering|
| step 8   | **08-spoke3-staticweb.ps1**   | powershell script to deploy the ARM template **08-spoke3-staticweb.json**           |
| step 9   | **09-frontdoor..json** | ARM template to create all the vnets (hub, spoke1,spoke2,spoke3, on-prem)  and vnet peering|
| step 9   | **09-frontdoor..ps1**  | powershell script to deploy the ARM template **09-frontdoor..json**                        |

## Collateral files
| file                      | description                                                               |       
| ------------------------- |:------------------------------------------------------------------------- |
| **fullset-udr-nsg.json**  | ARM template to deploy all NSGs and UDRs in in the vnets (hub, spoke1, spoke2,spoke2, onprem).<br> You do not need to run this ARM template to have the full project deployment. The ARM is only useful in the case you need to run  **01-vnets-hub.json** out of sequence. Running **01-vnets-hub.json** does not set the final configurations of NSGs and UDRs. **fullset-udr-nsg.json** guarantees the full list of setting for UDRs and NSGs |
| **fullset-udr-nsg.ps1**     | powershell script to deploy the ARM template **fullset-udr-nsg.json**    |
| **shutdownAppGateway1.ps1** |  powershell script to stop the Application Gateway 1 in spoke1 vnet      |
| **shutdownAppGateway3.ps1** |  powershell script to stop the Application Gateway 3 in spoke3 vnet      |
| **startAppGateway1.ps1**    |  powershell script to start the Application Gateway 1 in spoke1 vnet     |
| **startAppGateway3.ps1**    |  powershell script to start the Application Gateway 3 in spoke3 vnet     |

### <a name="customize the value of variables in init.json"></a>1.1 customize the value of variables in init.json
This is a preliminary step you can't skip. The value of variables in **init.json** file are used as input to all the ARM templates.

```json
{
    "subscriptionName": "NAME_OF_THE_AZURE_SUBSCRIPTION",
    "rgName": "RESOURCE_GROUP_NAME",
    "location": "AZURE_REGION_RESOURCE_GROUP",
    "locationonprem": "AZURE_REGION__ONPREM",
    "locationhub": "AZURE_REGION_HUB_NET",
    "locationspoke1": "AZURE_REGION_SPOKE1_VNET",
    "locationspoke2": "AZURE_REGION_SPOKE2_VNET",
    "locationspoke3": "AZURE_REGION_SPOKE2_VNET",
    "vnetHubName": "NAME_HUB_VNET",
    "vnetOnprem": "NAME_ONPREMISES_VNET",
    "vnetspoke1": "NAME_SPOKE1_VNET",
    "vnetspoke2": "NAME_SPOKE2_VNET",
    "vnetspoke3": "NAME_SPOKE3_VNET",
    "gateway1Name": "NAME_VPN_GATEWAY_IN_HUB_VNET",
    "gateway2Name": "NAME_VPN_GATEWAY_IN_ONPREM_VNET",
    "artifactsLocation": "WEB_SITE_URL_WHERE_ARE_PUBLISHED_THE_CUSTOM_SCRIPT_EXTENSION_SCRIPTS",
    "adminUsername": "ADMINISTRATOR_USENAME",
    "adminPassword": "ADMINISTRATOR_PASSWORD",
    "user1Name": "ADMINISTRATOR1_USENAME",
    "user1Password": "ADMINISTRATOR1_PASSWORD",
    "user2Name": "ADMINISTRATOR2_USENAME",
    "user2Password": "ADMINISTRATOR2_PASSWORD"
}
```

### <a name="step1"></a>1.2. <ins>step 1</ins>: running the ARM template 01-vnets-hub.json
- create the vnets: hub, spoke1, spoke2, spoke3, onprem
- create NSG and apply to the Tenant subnet in the hub vnet
- create azure VM with IIS in the Tenant subnet of the hub vnet
- create azure VM with IIS in the Tenant subnet of the onprem vnet
- create Azure vnet NAT gateway that enable external (public) connectivity and link the NAT Gateway to the Tenant subnet in the hub vnet
- deployment of Azure Bastion in the hub vnet 
- deployment of Azure Route Server in the hub vnet
- apply the Route Table to the Tenant subnet in the hub vnet. The UDR force the traffic in egress from the Tenant subnet to transit the oter vnets to pass through the Azure firewall 
- create vnet peering between hub-spoke1, hub-spoke2, hub-spoke3. The presence of Route Server in the hub allows in vnet peering, to set the attribute "Remote Gateway transit" to **true**. The onprem vnet is not in peering with hub vnet; the intent of onprem vnet is to simulate an on-premises network connect to the hub through site-to-site VPN tunnels 

The step 1 establishes the pattern for all subsequent steps.

[![4]][4]

**Validation** <br>
- in the Azure Management Portal browse to the Azure Resource Group 
- verifying the presence of all vnets, hub, spoke1, spoke2, spoke3, onprem. 
- connect to the VM in the Tenant subnet of the hub through Azure Bastion. Check the role of IIS. Inside the VM, connect to the local IIS: http://127.0.0.1 The web page should be visualized. if IIS is not installed, check out the customer script extension logs in local VM (folder: C:\WindowsAzure\Logs\Plugins\Microsoft.Compute.CustomScriptExtension\1.10.15\)
- check the presence the NSG applied to the Tenant subnet of hub vnet
- by Azure Management Portal verifying the vnet peering hub-spoke1, hub-spoke2, hub-spoke3
- browse in the hub subnets:
   - check the association of Tenant subnet with vnet NAT Gateway
   - the NSG s applied to the Tenant subnet 
   - UDR applied to the Gateway


### <a name="step2"></a>1.3 <ins>step 2</ins>: deployment of Azure security policy and Azure firewall in the hub vnet
- define the Azure security Policy for the Azure Firewall. The Azure firewall security policy includes Network, Application and DNAT rules
- create the Azure Firewall in hub vnet and associated the security policy
- create the Azure Log Analytics workspace
- define the Azure firewall logs to be sent to the load analytics workspace

[![5]][5]

**Azure firewall- Network Rules**
| Rule name               | Source                                                           | Port        | Protocol | Destination                                                      | Action |
| ----------------------- | ---------------------------------------------------------------- | ----------- | -------- | ---------------------------------------------------------------- | ------ |
| allow-web-hub-to-spoke  | 10.0.1.0/24                                                      | 80,443      | TCP      | 10.1.0.0/16, 10.2.0.0/16, 10.3.0.0/16, 10.10.0.0/16              | Allow  |
| allow-SMB-spoke2        | 10.0.0.0/16, 10.1.0.0/16, 10.2.0.0/16, 10.3.0.0/16, 10.10.0.0/16 | 445,137,139 | Any      | 10.2.0.0/16                                                      | Allow  |
| allow-web-spoke1-spoke3 | 10.1.0.0/16, 10.3.0.0/16                                         | 80,443      | TCP      | 10.1.0.0/16, 10.3.0.0/16                                         | Allow  |
| allow-RDP-spoke2-spoke3 | 10.2.0.0/16, 10.3.0.0/16                                         | 3389        | TCP      | 10.2.0.0/16, 10.3.0.0/16                                         | Allow  |
| onprem-to-vnets         | 10.10.0.0/16                                                     | \*          | Any      | 10.0.0.0/16, 10.1.0.0/16, 10.2.0.0/16, 10.3.0.0/16               | Allow  |
| Allow-ICMP              | 10.0.0.0/16, 10.1.0.0/16, 10.2.0.0/16, 10.3.0.0/16, 10.10.0.0/16 | \*          | ICMP     | 10.0.0.0/16, 10.1.0.0/16, 10.2.0.0/16, 10.3.0.0/16, 10.10.0.0/16 | Allow  |

A network diagram with graphical representation of <ins>network security rules</ins> in Azure firewall is shown below:

[![6]][6]
[![7]][7]

### <a name="step3"></a>1.4 <ins>step 3</ins>: site-to-site VPN between hub vnet and onprem vnet
- create the VPN Gateway in hub vnet 
- create the VPN Gateway in the onprem vnet
- establish two site-to-site VPN tunnels between the VPN gateway in hub VNet and VPN gateway in onprem VNet

[![8]][8]

At the end of deployment verifying the presence of two public IPs associated with VPN Gateway1 deployed in hub vnet, two public IPs associated with VPN Gateway2 deployment in on-prem vnet. There are in total 4 Connection objects.

### <a name="step4"></a>1.5 <ins>step 4</ins>: spoke2 vnet
- create an Azure load balancer in spoke2 vnet
- create Windows VMs in the backend pool of the load balancer in spoke2
- by custom script extension install IIS and shared folder in the Windows VMs in spoke2


[![9]][9]

### <a name="step5"></a>1.6 <ins>step 5</ins>: static web in storage account connected to the spoke2 vnet through private endpoint
- create a storage account in the same region of spoke2 vnet
- create a "User Assigned Identity" to access to the storage account in spoke2
- assign **"Storage Account Contributor"** role (17d1049b-9a84-46fb-8f53-869881c3d3ab) to the user assigned identity
- create a static web site in the storage account 
- create a private endpoint to access to the static web site
- create a private DNS zone for the web site
- link the private DNS zone to the spoke2 vnet

[![10]][10]

### <a name="step 6"></a>1.7 <ins>step 6</ins>: spoke1 vnet
- create the application gateway in spoke1 
- create Azure VMs as backend of Application Gateway
- by custom script extension install IIS in the windows VMs with web page pointing to the IP of the load balancer in the spoke2
- the IIS web page contains a link to the private endpoint for static web page running in Azure storage account


[![11]][11]

### <a name="step 7"></a>1.8 <ins>step 7</ins>: spoke3 vnet
- create an Azure load balancer in spoke3 vnet
- create Windows VMs in the backend pool of the load balancer in spoke3
- by custom script extension, install IIS in the Windows VMs in spoke3


[![12]][12]

### <a name="step 8"></a>1.9 <ins>step 8</ins>: static web in storage account nd private endpoint for the connection with spoke3 
- create a storage account in the same region of spoke3 vnet
- create a static web site in the storage account 
- create a private endpoint in spoke3 to access to the static web site
- link the spoke3 vnet to the Azure private DNS zone

[![13]][13]

### <a name="step 9"></a>1.10 <ins>step 9</ins>: Azure Front door
- create the Front Door with origin to the public IPs of the Application Gateways in spoke1 and spoke3. An endpoint domain names is automatically generated. The endpoint domain name has the following structure: myendpoint-mdjf2jfgjf82mnzx.z01.azurefd.net


[![14]][14]


## <a name="paths of data  traffic"></a>2. UDRs
The ARM templates configure different UDRs applied to the subnets; the picture below reports a visual of the UDRs.
 
[![15]][15]

## <a name="paths of data  traffic"></a>3. Paths of data  traffic
Transit of data is determinated by UDRs and Azure firewall security rules.
Below few diagrams with data paths.

[![16]][16]

The Azure hub-vm1 gets access to internet across the vnet NAT Gateway. There are in internet few web sites providing information about the public IP of HTTP/HTTPS request. Verification of transit through the vnet NAT Gateway can be done connecting through an internet through one of those web sites.

[![17]][17]

[![18]][18]

HTTP requests in Windows can be done through command line:
```powershell
Invoke-WebRequest -Uri http://IP_ADDRESS
```

Login in the onprem-vm1 VM and run the following command to check the HTTP connection to the web servers:
```powershell
Invoke-WebRequest -Uri http://10.1.1.4
Invoke-WebRequest -Uri http://10.1.1.5
Invoke-WebRequest -Uri http://10.2.2.50
Invoke-WebRequest -Uri http://10.3.1.4
Invoke-WebRequest -Uri http://10.3.1.5
```

`Tags: virtual datacenter, hub-spoke` <br>
`date: 24-05-23`

<!--Image References-->

[1]: ./media/network-diagram.png "network diagram"
[2]: ./media/ip-assigments.png "ip address assigments"
[3]: ./media/step-sequence.png "sequence of steps to run the full deployment"
[4]: ./media/step1.png "step1: create all the vnets and vnet peering, Route Server"
[5]: ./media/step2.png "step2: create azure firewall in the hub vnet"
[6]: ./media/security-policy1.png "Azure firewall network security rules"
[7]: ./media/security-policy2.png "Azure firewall network security rules"
[8]: ./media/step3.png "step3: create VPN Gateways and site-to-site VPN between hub vnet and onprem vnet"
[9]: ./media/step4.png "step4: create spoke2 vnet"
[10]: ./media/step5.png "step5: create static web in storage account and private endpoint in spoke2 vnet to connect to the web site"
[11]: ./media/step6.png "step6: create spoke1 with application and windows VMs in the backend. A customs script extension deploys IIS in the VMs"
[12]: ./media/step7.png "step7: create spok3 vnet with application gateway and windows VMs in the backend. A customs script extension deploys IIS in the VMs"
[13]: ./media/step8.png "step8: create a static web site and private endpoint to connect the web site to the spoke3 vnet"
[14]: ./media/step9.png "step9: create Azure front door. the front door origin reference the public IPs of the Application Gateways in spoke1 and spoke3"
[15]: ./media/udr.png "UDR applied to the subnets"
[16]: ./media/datapath1.png "access from internet to the web servers in spoke1 and spoke3"
[17]: ./media/datapath2.png "access from internet to the web server in Tenant subnet of hub vnet through the Azure firewall"
[18]: ./media/datapath3.png "access from on-premises to the web servers in hub and spoke vnets"

<!--Link References-->

