<properties
pageTitle= 'Deployment of Azure VMs with transit through Azure Firewall using Terraform'
description= "Deployment of Azure VMs with transit through Azure Firewall using Terraform"
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
   ms.workload="Terraform, Azure firewall, Azure Bastion"
   ms.date="18/07/2022"
   ms.review=""
   ms.author="fabferri" />

# Deployment of Azure VMs with transit through Azure Firewall using Terraform
The article walks you through a single VNet with ubuntu VMs deployed in different subnet with transit through Azure firewall. The network diagram is shown below:

[![1]][1]

* UDRs are applied to the application subnets **app1Subnet** and **app2Subnet** to force the traffic, VM-to-VM and VM-to-internet, to transit through the Azure Firewall  
* the Azure Firewall is deployed in the **AzureFirewallSubnet** subnet that has a minimum /26 network prefix 
* The Azure Bastion host is deployed in the **AzureBastionSubnet** subnet that has a minimum /26 network prefix
* The two linux VMs are created by Terraform meta-argument **count**. The count meta-argument accepts a integer number, and creates many instances of the resource or module.
* Azure custom script extension are used to execute scripts on Azure VMs for post deployment configuration; the local bash script **linux-nginx.sh** makes a silent installation of nginx with custom homepage. With terraform the local Linux script must be base64 encoded; this is can be done with the **base64encode** native function.


## <a name="list of files"></a>2. File list

| File name                | Description                                                                    |
| ------------------------ | ------------------------------------------------------------------------------ |
| **main.tf**              | Terraform HCL configuration file                                               |
| **terraform.tfvars.json**| Terraform automatically loads the value of the variables specified in the file |
| **linux-nginx.sh**       | local bash script used in Azure custom script extension; it installs nginx with custom homepage in the Azure VMs|

Before running, edit the file **terraform.tfvars.json** and replace the values of **ADMINISTRATOR_USERNAME**, **ADMINISTRATOR_PASSWORD** with your values.

## <a name="how to deploy"></a>3. How to deploy
Before going to deploy resources in the Azure subscription, verifying you are in right context:

```az
az account show
az account set --subscription <SUBSCRIPTION_NAME>
```

### STEP1: Run terraform init to initialize the Terraform deployment
```console
terraform init
```
### STEP2: Create a Terraform execution plan
```console
terraform plan -out main.tfplan
```
Terraform automatically loads a number of variable definitions files if named exactly the following way: **terraform.tfvars** or **terraform.tfvars.json**

* The terraform plan command creates an execution plan, but doesn't execute it. Instead, it determines what actions are necessary to create the configuration specified in your configuration files. This pattern allows you to verify whether the execution plan matches your expectations before making any changes to actual resources.
* The optional **-out** parameter allows you to specify an output file for the plan. Using the **-out** parameter ensures that the plan you reviewed is exactly what is applied.

### STEP3: Run terraform apply to apply the execution plan to your cloud infrastructure
```console
terraform apply main.tfplan
```

**NOTE**
* the **terraform apply** command above assumes you previously ran **terraform plan -out main.tfplan**
* if you specified a different filename for the **-out** parameter, use that same filename in the call to terraform apply
* if you didn't use the **-out** parameter, simply call **terraform apply** without any parameters

```console
terraform plan -out <FILE_NAME>.tfplan
```

### Clean up resources
When the resources created via Terraform are no longer required, you can delete it:

```console
terraform apply -destroy
```

## <a name="traffic paths"></a>4. Traffic paths
The network diagram shows the traffic paths:

[![2]][2]

`Tags: Terraform, Azure firewall, Azure Bastion`
`date: 18-07-22`

<!--Image References-->

[1]: ./media/network-diagram.png "network diagram"
[2]: ./media/network-diagram2.png "traffic paths"
<!--Link References-->

