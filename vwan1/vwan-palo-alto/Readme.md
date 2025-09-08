<properties
pageTitle= 'Azure Virtual WAN single hub with two spoke VNets and Palo Alto cloud NGFW'
description= "Azure Virtual WAN single hub with two spoke VNets and Palo Alto cloud NGFW"
services="Azure Virtual WAN"
documentationCenter="github"
authors="fabferri"
editor="fabferri"/>

<tags
   ms.service="configuration-Example-Azure"
   ms.devlang="terraform"
   ms.topic="article"
   ms.tgt_pltfrm="azure"
   ms.workload="Virtual WAN"
   ms.date="28/08/2025"
   ms.author="fabferri" />

## Azure Virtual WAN single hub with two spoke VNets and Palo Alto cloud NGFW

This article includes Terraform scripts for deploying a Virtual WAN (vWAN) with a single virtual hub and two spoke virtual networks.
A Palo Alto Next Generation Cloud Firewall (NGFW) is provisioned as a SaaS service within the virtual hub.
The network architecture is illustrated in the diagram below.

![1][1]

Deployment of vWan, virtual hub1, spoke Vnets and peering is executed by terraform scripts.<br>
Deployment and configuration of Palo Alto cloud Next Generation firewall and routing intent is executed throught the Azure management portal. <br>

### <a name="deployment setup"></a>1. Deployment Setup: Sequential Steps

1. Deploy vWAN and vnets (Terraform)
   - Use a Terraform script to deploy:
      - Azure Virtual WAN (vWAN)
      - Virtual Hub 1
      - Spoke VNets
      - VNet peering
1. Deploy Virtual Machines (Terraform)
   - Use a Terraform script to provision the required VMs.
1. Deploy Palo Alto Cloud NGFW (Azure Portal)
   - Use a Terraform script to provision the required VMs.
1. Configure Route Intent in vWAN (Azure Portal)
   - Deploy route intent in the vWAN via the Azure Portal.
1. Customize Firewall Rules (Azure Portal)
   - Modify rules in the Local Rulestack for the Cloud NGFW.
   - Enable logging for traffic inspection.
1. Set Up Logging
   - Create a Log Analytics workspace.
   - Enable logging in the Palo Alto Cloud NGFW to send logs to Log Analytics.
1. Reference the log Analytics in Palo Alto cloud NGFW
1. Install simple Workloads in Azure spoke VMs
   - Set up simple workloads in:
      - vm1-1
      - vm2-1
1. Validate Traffic Flows and Logging
   - Generate traffic between **vm1-1** and **vm2-1**.
   - Verify that logs are correctly captured in Log Analytics.


## <a name="terraform scripts"></a>2. Deploy vWAN and vnets (Terraform)

The **1** folder contains Terraform scripts to deploy the Virtual WAN (vWAN), including the virtual hub (**hub1**), and three virtual networks: **vnet1**, **vnet2**, and **vnet90**. It also configures connections between **vnet1** and **vnet2** and the virtual hub. <br>
Before running the scripts, update the value in the **terraform.tfvars** file to match your environment:

```
subscription_id = "SUBSCRIPTION_ID"
```

Commands to execute the deployment:

`az login --scope https://graph.microsoft.com/.default`  <br>
`az account set -s $subscriptionName`  : set the context; replace $subscriptionName by name of Azure subscription <br>
`az account show`                      : show context information <br>

`terraform init -upgrade` <br>
`terraform plan -out main.tfplan` <br>
`terraform apply main.tfplan` <br>


## <a name="terraform scripts"></a>3. Deploy Virtual Machines (Terraform)

The **2** folder contains Terraform scripts for deploying Ubuntu virtual machines (VMs) in the virtual networks.
Before running the scripts, update the values in the **terraform.tfvars** file to match your environment:

```console
subscription_id = "SUBSCRIPTION_ID"
admin_username = "VM_ADMINISTRATOR_USERNAME"
admin_password = "VM_ADMINISTRATOR_PASSWORD"
```

Run the following commands in **2** folder: <br>
`terraform init -upgrade` <br>
`terraform plan -out main.tfplan` <br>
`terraform apply main.tfplan` <br>


## <a name=" deploy Palo Alto Cloud NGFW"></a>4. Deploy Palo Alto Cloud NGFW (Azure Portal)

In Azure portal select the **hub1** in vWAN and create **Palo Alto Cloud Next Generation Firewall**

![2][2]

Define firewall name, location and marketplace plan"
![3][3]

Define the networking, with public IPs for egress traffic and public IP for source NAT:

![4][4]

Specify the default security policies and the name of the local Ruleset:

![5][5]

Accept terms and conditions:

![6][6]

Review the setting before spinning up the Palo Alto Cloud NGFW:

![7][7]

When deployment is completed two new objects are automatically created: **Cloud NGFW by Palo Alto Networks** and **Local Rulestack for Cloud NGFW by Palo Alto Networks**:

![8][8]

The security rules are stored in the Local Rulestack. <br>
The status of **Cloud NGFW by Palo Alto Networks** should be healty:

![9][9]

in  **Cloud NGFW by Palo Alto Networks** is visibile the marketplace details and management properties:

**Offer Id: pan_swfw_cloud_ngfw** <br>
**Publisher Id: paloaltonetworks** <br>

**Is panorama managed: FALSE** <br>
**Is strata cloud managed: FALSE** <br>

In this case the firewall is managed by Cloud Stack:

![10][10]

## <a name="routing intent"></a>5. Configure Routing Intent in vWAN (Azure Portal)

When the deployment of Palo Alto Cloud Next Generation Firewall is completed, you can proceed in the vWAN Routing Intent:

![11][11]

- select "SaaS solution" from the drop down of Internet traffic and Next Hop Resource as **Cloud NGFWservice** created, in order to secure Internet inbound and outbound traffic using **Cloud NGFW**
- to secure private traffic(Spoke to Spoke and Spoke) select "SaaS solution" from the drop down of Private traffic and Next Hop Resource as **Cloud NGFW** service created

The routing table in the **hub1**:

![12][12]

## <a name="customize firewall rules"></a>6. Customize Firewall Rules (Azure Portal)

Setting the IP prefixes for **vnet1** and **vnet2**:

![13][13]

![14][14]

![15][15]

The full prefix list created is shown below:

![16][16]

Create rules, one rule to allow the traffic from vnet1 to vnet2 and one rule from vnet2 to vnet1.

| name         | source match criteria | destination match criteria | Protocol & Port | action  | logging |
| :----------- | :-------------------- | :------------------------- |:--------------- | :------ | :------ |
|  vnet1-vnet2 |  Prefix List: vnet1   | Prefix List: vnet2         | any             | allow   | on      |
|  vnet2-vnet1 |  Prefix List: vnet2   | Prefix List: vnet1         | any             | allow   | on      |

![17][17]

List of defined Rules:

![18][18]

## <a name="logging"></a>7. Set Up Logging

CloudNGFWpolicies can be managedusing Azure Portal Rulestack or using Palo Alto Panorama.

- If the policies are managed using Panorama, all the traffic logs can be monitored using Panorama or log collector.
- If the policies are managed using Rule stack, traffic processed by Cloud NGFW service will be logged into Azure Cloud native Log Analytics Workspace.

In our case policies using Rulestack manages the rule policies and hence we are going to configure log Analiytics and Log settings to redirect logs to Azure Log Analytics workspace.


Palo Alto Cloud NGFW requires a log Analysics workspace. <br>
From Azure marketplace search for  log Analysics workspace:

![19][19]

Creation of log Analyticis:

![20][20]

## <a name="logging"></a>7. Reference the log Analytics in Palo Alto cloud NGFW

![21][21]

### <a name="execute deployments by terraform"></a>9. Install simple Workloads in Azure spoke VMs

You can't connect directly to the Azure spoke VMs when routing intert in vWAN is set to Internet becasue the default route 0/0 is added to the system routing of spoke vnets with next-hop the IP of the SaaS solution in the hub1 (in our case Palo Alto cloud NGFW). <br>
You can use the **vm90-1** as jumpbox. The Azure ubuntu VMs are created with RSA key authetication. A linuxkey.pem file is created by the terraform scrips in **2** folder. It is required to copy the linuxkey.pem file from your local windows host to the Azure **vm1-1** and **vm2-1**:

```console
scp -i privatekey pathFileOnWindows user@publicIp:pathDirectoryLinux

scp -i linuxkey.pem .\linuxkey.pem user@<vm90-1_pubIP>:~/
```

On the **vm90-1** login to the **vm1-1** and change the permission on the RSA private key file:

```bash
vm90-1:~$ chmod 600 linuxkey.pem
```

To commect from **vm90-1** jumpbox to **vm1-1** and **vm2-1**:
```bash
vm90-1:~$ ssh edge@10.101.1.4 -i linuxkey.pem
vm90-1:~$ ssh edge@10.101.2.4 -i linuxkey.pem
```

Install iperf3 and nginx on **vm1-1** and **vm2-1** than customize the nginx homepage:

```bash
vm1-1:~$ cat /etc/hostname > /var/www/html/index.nginx-debian.html
vm2-1:~$ cat /etc/hostname > /var/www/html/index.nginx-debian.html
```

### <a name="validate traffic flows"></a>10. Validate Traffic Flows and Logging

Checking the effective routing table in **vm1-1** **vm2-1**:

![22][22]

![23][23]

Generate HTTP traffic between the VMs in the spoke vnets:

```bash
while true; sleep 0.2s; do curl http://10.101.1.4; done
```

Checking the firewall logs:

![24][24]


## ANNEX: how to get ready with terraform

1. install the AZ CLI
1. download terraform: (https://developer.hashicorp.com/terraform/install) <br>
The .zip file contains <ins>LICENSE.txt</ins> and <ins>**terraform.exe**</ins>
1. copy those files to a folder, i.e. C:\terraform
1. Update your system's global PATH environment variable to include the directory that contains the terraform executable. In Windows the path is in the registry but usually you edit through this interface: <br>
   - Go to **System ->About -> Advanced system settings -> Advanced -> Environment Variables**
   - Scroll down in system variables until you find PATH.
   - Click **NEW**
   - Add the path: **C:\terraform**
1. logout and login in Windows to take effect of the PATH change
1. in powershell check the path: `echo $env:path`
1. check the version by command: `terraform -version` <br>
1. to run a deployment: <br>
   `terraform init -upgrade` <br>
   `terraform plan -out main.tfplan` <br>
   `terraform apply main.tfplan` <br>

if you want to replace a specific reosurce after a deployment, i.e. a connection: <br>
`terraform apply -replace="azurerm_virtual_hub_connection.hubconnection12"`

if you should issue with azure authetication, run: <br> 
`az login --scope https://graph.microsoft.com/.default` <br> <br>

if you your Azure subscription is in different Entra tenant use the command: <br> 
`$tenantId= 'ENTRA_TENANT_ID'` <br>
`az login --tenant $tenantId ` <br> 

`Tags: Virtal WAN, vWAN, Terraform, Palo Alto NGFW` <br>
`date: 09-01-2025` <br>

<!--Image References-->

[1]: ./media/network-diagram.png "network diagram"
[2]: ./media/createfw-01.png "create Palo Alto Cloud NGFW"
[3]: ./media/createfw-02.png "create Palo Alto Cloud NGFW"
[4]: ./media/createfw-03.png "create Palo Alto Cloud NGFW"
[5]: ./media/createfw-04.png "create Palo Alto Cloud NGFW"
[6]: ./media/createfw-05.png "create Palo Alto Cloud NGFW"
[7]: ./media/createfw-06.png "create Palo Alto Cloud NGFW"
[8]: ./media/createfw-07.png "create Palo Alto Cloud NGFW"
[9]: ./media/createfw-08.png "create Palo Alto Cloud NGFW"
[10]: ./media/createfw-09.png "create Palo Alto Cloud NGFW"
[11]: ./media/routing-intent01.png "routing intent"
[12]: ./media/routing-intent02.png "routing intent"

[13]: ./media/prefix-list01.png "prefix list"
[14]: ./media/prefix-list02.png "prefix list vnet1"
[15]: ./media/prefix-list03.png "prefix list vnet2"
[16]: ./media/prefix-list04.png "prefix list"
[17]: ./media/rules01.png "security rules"
[18]: ./media/rules02.png "list of security rules"
[19]: ./media/log-analytics01.png "log analytics creation"
[20]: ./media/log-analytics01.png "log analytics creation"
[21]: ./media/fw-log-settings01.png "reference log Analytics in Palo Alto cloud NGFW"
[22]: ./media/vm1-1-effective-routing-table.png "vm1-1 effective routing table"
[23]: ./media/vm2-1-effective-routing-table.png "vm1-1 effective routing table"
[24]: ./media/firewall-logs-in-log-analytics01.png "logging traffic"

<!--Link References-->
