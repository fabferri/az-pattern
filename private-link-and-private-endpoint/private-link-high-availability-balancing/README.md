<properties
pageTitle= 'Private Link service in high availability configuration through Azure Application Gateway' 
description= "Private Link service in high availability configuration through Azure Application Gateway"
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
   ms.workload="Azure private link, Azure Application Gateway, Azure Load Balancer"
   ms.date="05/04/2023"
   ms.review=""
   ms.author="fabferri" />

# Private Link service in high availability configuration through Azure Application Gateway

The article describes a configuration with two Azure Private Link service deployed in two different provider vnets and single consumer vnet with access to the Private Link service:

[![1]][1]

The design allows to achieve a private link service configuration in high availability for HTTP and HTTPS traffic in load balancing. 
Let describe the main characteristics of the configuration.
- In the consumer vnet are present two private endpoints **ep1** and **ep2**, to reach out respectively the private link services in **vnetprodurer1** and **vnetproducer2**. 
- In each provider vnet is deployed the private link service, connected to an Azure Standard Load Balancer configured in HA ports. The backend of Azure Load Balancer in each producer vnet is configured to balance the traffic to two Ubuntu VMs with apache web server, configured to answer to HTTP requests on default TCP port 80 
- The Application Gateway v2 deployed in the consumer vnet has the role to balance the traffic between the private endpoint **ep1** and **ep2**. The frontend IP is connected to Gateway subnet and in the backendpool are defined the two private endpoints **ep1** and **ep2** connected to a Private Link services.
- The configuration has two type of health probes: health probe generated from the Azure load balancers in the producer vnet and health probe generated from the Application Gateway in the consumer vnet. Load Balancer health probes are originated from the IP address 168.63.129.16 and must not be blocked to mark your web instance as up.
- The Application Gateway has health probe set to the default, sending HTTP requests on port 80. The health probe messages of Application Gateway reach out the private endpoints in the backend pool and then are forwarded to the the private link service in the production vnet. When the health probe message of Application Gateway come out from the private link service in the production vnets, the source IP takes the NAT IP of Private Link service. The Private Link services in the production vnets have the following NAT IPs: <br>
**privateLinkSrv1** NAT IP: 10.0.1.68 <br>
**privateLinkSrv1** NAT IP: 10.0.2.68 <br>
To avoid Application Gateway health probe messages reach out a web server in status down, the heath probe interval should be double (or higher) than the time interval of Azure Load Balancer. By this design, the health probe of Application Gateway should have low probability to reach out the wrong web server in status down. <br>
In the Azure Load Balancer the minimum value of the health probe interval is 5 seconds; the Application Gateway health probe interval could be set to 10 seconds.


Balancing of the traffic through the Azure Application Gateway in the consumer vnet is shown below:

[![2]][2]

**NOTE** <br>
The configuration of this post deploy an Application Gateway v2  Private IP address only in the frontend IP configuration. The feature is currently in public preview. Follow the official documentation about [how to enable the Private IP address only frontend IP configuration](https://learn.microsoft.com/en-us/azure/application-gateway/application-gateway-private-deployment) in the Application Gateway v2.


## <a name="list of project files"></a>1. Project files

| File name                 | Description                                                                      |
| ------------------------- | -------------------------------------------------------------------------------- |
| **init.json**             | it contains the input variables setting used for the full deployment             |
| **provider1.json**        | ARM template to deploy the provider1 vnet with private link service1, load balancer in HA and backend Ubuntu VMs <br> Apache web server is installed in the VMs through custom script extension                      |
| **provider1.ps1**         | powershell script to run **provider1.json**                                      |
| **provider2.json**        | ARM template to deploy the provider2 vnet with private link service2, load balancer in HA and backend Ubuntu VMs <br> Apache web server is installed in the VMs through custom script extension                      |
| **provider1.ps1**         | powershell script to run **provider2.json**                                      |
| **consumer.json.json**    | ARM template to deploy the consumer vnet with private endpoints **ep1** and **ep2** to access to the private link services1 and private link service2 |
| **appgtw.json**           | ARM template to deploy Azure Application Gateway in consumer vnet                |
| **appgtw.ps1**            | powershell script to run **appgtw.json**                                         |
| **fetch-privIP-private-endpoint.json** | ARM template to collect the IP address of private endpoints **ep1** **ep2** in the consumer vnet |
Before running the powershell scripts, customize the values of input variables in the **init.json**:
```json
{
"provider1SubscriptionName": "AZURE_SUBSCRIPTION_NAME_TO_DEPLOY_PROVIDER1_NET",
"provider2SubscriptionName": "AZURE_SUBSCRIPTION_NAME_TO_DEPLOY_PROVIDER2_NET",
"consumerSubscriptionName": "AZURE_SUBSCRIPTION_NAME_TO_DEPLOY_CONSUMER_NET",
"Provider1ResourceGroupName": "RESOURCE_GROUP_NAME_PROVIDER1",
"Provider2ResourceGroupName": "RESOURCE_GROUP_NAME_PROVIDER2",
"ConsumerResourceGroupName": "RESOURCE_GROUP_NAME_CONSUMER",
"provider1Location": "AZURE_REGION_PROVIDER1_NET",
"provider2Location": "AZURE_REGION_PROVIDER2_NET",
"consumerLocation": "AZURE_REGION_CONSUMER_NET",
"adminUsername": "ADMINISTRATOR_USERNAME",
"adminPassword": "ADMINISTRATOR_PASSWORD"
}

```
Utilization of file **init.json** helps to keep the values of variables consistent across the deployments.
<br>

The sequence for the full project deployment is shown above:

[![3]][3]

The script script **check.sh** can be used in the consumer network to check the HTTP connections to the web servers in the production vnets.


`Tags: Azure private link, Azure Application Gateway, Azure Load Balancer, HA ` <br>
`date: 05-04-23`

<!--Image References-->

[1]: ./media/network-diagram1.png "network diagram"
[2]: ./media/network-diagram2.png "data traffic balanced through the application Gateway"
[3]: ./media/sequence.png "setup sequence"

<!--Link References-->

