<properties
pageTitle= 'Site-to-Site VPN between two Azure VPN Gateways with static routing deployed by Terraform'
description= "Site-to-Site VPN between two Azure VPN Gateways with static routing deployed by Terraform"
services="Azure VPN"
documentationCenter="github"
authors="fabferri"
editor="fabferri"/>

<tags
   ms.service="configuration-Example-Azure"
   ms.devlang="terraform"
   ms.topic="article"
   ms.tgt_pltfrm="azure"
   ms.workload="Azure Site-to-Site VPN"
   ms.date="09/01/2025"
   ms.author="fabferri" />

## Site-to-Site VPN between two Azure VPN Gateways with static routing deployed through Terraform
This article provides Terraform scripts to create two virtual networks (VNets), vnet1 and vnet2, connected through a Site-to-Site VPN using Azure VPN Gateways. <br>
The Azure VPN Gateway are configured in active-active and static routing and deployed as zonal gateways (SKUs: "VpnGw1AZ", "VpnGw2AZ", "VpnGw3AZ", "VpnGw4AZ", "VpnGw5AZ")<br>
The network diagram is shown below:

![1][1]

Appying the terraform plan generates two text files in local folder: 
- **psk.txt**: it contains the shared secret applied to the IPsec tunnels 
- **vm-admin-credential.txt**: it contains the administrator username and password of the vm1 and vm2 
<br>

The network diagram presents thorough details:

![2][2]

In **version 4.0 of the Azure Provider**, it's mandatory to specify the <ins>Azure Subscription ID</ins> when configuring a provider instance in your configuration. More detail can be find in [terraform documentation](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/guides/4.0-upgrade-guide#specifying-subscription-id-is-now-mandatory). <br>
Before starting the terraform deployment you need to specify the subscriptionId inside the **providers.tf**:
```console
terraform {
  required_version = ">=1.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.15.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6.3"
    }
    local = {
      source  = "hashicorp/local"
      version = "> 2.5.0"
    }
  }
}
provider "azurerm" {
  features {}
  subscription_id = "00000000-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
}
```
Replace the string 00000000-xxxx-xxxx-xxxx-xxxxxxxxxxxx with your subscriptionId value. <br>

Commands to execute the deployment: <br>
`az login`                             : login in the Azure  <br>
`az account set -s $subscriptionName`  : set the context, $subscriptionName is Azure subscription name <br>
`az account show`                      : show context information <br>

`terraform init -upgrade` <br>
`terraform plan -out main.tfplan` <br>
`terraform apply main.tfplan` <br>

## NOTE
At anytime after the deployment, you can display the values of output variables by command: `terraform output` <br>
If the variables are created with sentive attribute the value won't be shown. You can use the command **terraform output -raw <NAME_VARIABLE>** to diplay the sentive values: <br>
`terraform output -raw psk` <br>
`terraform output -raw vm_admin_password` <br>

Powershell commands to fetch details on Site-to-Site VPN tunnels:
```powershell
$rgName='rg-vpn'
$vpnName='gw1'
$connectionName11='gwconn11'
Get-AzVirtualNetworkGatewayBGPPeerStatus -VirtualNetworkGatewayName $vpnName -ResourceGroupName $rgName |ft
$peer1=(Get-AzVirtualNetworkGatewayBGPPeerStatus -VirtualNetworkGatewayName $vpnName -ResourceGroupName $rgName).LocalAddress[0]
$peer2=(Get-AzVirtualNetworkGatewayBGPPeerStatus -VirtualNetworkGatewayName $vpnName -ResourceGroupName $rgName).LocalAddress[1]
Get-AzVirtualNetworkGatewayAdvertisedRoute -VirtualNetworkGatewayName $vpnName -ResourceGroupName $rgName -Peer $peer1 | ft
Get-AzVirtualNetworkGatewayLearnedRoute -VirtualNetworkGatewayName $vpnName -ResourceGroupName $rgName

Get-AzVirtualNetworkGatewayConnection -Name $connectionName11 -ResourceGroupName $rgName
(Get-AzVirtualNetworkGatewayConnection -Name $connectionName11 -ResourceGroupName $rgName).ConnectionStatus
(Get-AzVirtualNetworkGatewayConnection -Name $connectionName11 -ResourceGroupName $rgName).EgressBytesTransferred
(Get-AzVirtualNetworkGatewayConnection -Name $connectionName11 -ResourceGroupName $rgName).IngressBytesTransferred

# shared key associated with the VPN connection
Get-AzVirtualNetworkGatewayConnectionSharedKey -Name $connectionName11 -ResourceGroupName $rgName
```

Az CLI commands to fetch information on Site-to-Site VPN tunnels:  
```powershell
$rgName='rg-vpn'
$vpnName='gw1'
$connectionName11='gwconn11'
az network vpn-connection show --name $connectionName11 --resource-group $rgName
az network vpn-connection show --name $connectionName11 --resource-group $rgName --query tunnelConnectionStatus

az network vnet-gateway list-learned-routes -n $vpnName -g $rgName  -o table
az network vnet-gateway list --query [].[name,bgpSettings.asn,bgpSettings.bgpPeeringAddress] -o table -g $rgName
az network vnet-gateway list --query "[?name=='gw1'].[name,bgpSettings.bgpPeeringAddress,bgpSettings.asn]" -o table -g $rgName
az network vnet-gateway list --query "[?name=='gGw1'].{Name:name,BGPlocalIP:bgpSettings.bgpPeeringAddress,ASN:bgpSettings.asn}" -o table -g $rgName
az network vnet-gateway list-advertised-routes -n $vpnName -g $rgName --peer $peer1
az network vnet-gateway list-learned-routes -n $vpnName -g $rgName  -o table

# shared key associated with the VPN connection
az network vpn-connection shared-key show --connection-name $connectionName11 --resource-group $rgName
```

## ANNEX: how to start
1. download terraform: (https://developer.hashicorp.com/terraform/install) <br>
The .zip file contains <ins>LICENSE.txt</ins> and <ins>**terraform.exe**</ins>
1. copy those files to a folder, i.e. C:\terraform
1. Update your system's global PATH environment variable to include the directory that contains the terraform executable.
In Windows the path is in the registry but usually you edit through this interface: <br>
Go to **System -> About -> Advanced system settings -> Advanced -> Environment Variables** <br>
Scroll down in system variables until you find PATH and click NEW. <br> 
Add the path to the terraform binary: **C:\terraform**
1. logout and login in Windows to take effect of the PATH changed
1. in powershell check the PATH variable includes the folder to terraform binary: `echo $env:path`
1. check the version by command: `terraform -version` <br>
1. to run a deployment: <br>
   `terraform init -upgrade` <br>
   `terraform plan -out main.tfplan` <br>
   `terraform apply main.tfplan` <br>

> [!NOTE]
> if you should issue with azure authetication, run: <br> `az login --scope https://graph.microsoft.com/.default`
>

<br><br>



`Tags: Site-to-Site VPN, Terraform` <br>
`date: 15-01-2025` <br>

<!--Image References-->

[1]: ./media/network-diagram.png "high level network diagram"
[2]: ./media/network-diagram2.png "network diagram with Site-to-Site VPN details"

<!--Link References-->

