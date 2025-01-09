<properties
pageTitle= 'Site-to-Site VPN between two Azure VPN Gateways deployed by Terraform'
description= "Site-to-Site VPN between two Azure VPN Gateways deployed by Terraform"
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

## Site-to-Site VPN between two Azure VPN Gateways deployed through Terraform
This article provides Terraform scripts to create two virtual networks (VNets), vnet1 and vnet2, connected through a Site-to-Site VPN using Azure VPN Gateways. <br>
Two IPsec tunnels are established between the Azure VPN gateways, which are deployed with zonal gateways (SKUs: "VpnGw1AZ", "VpnGw2AZ", "VpnGw3AZ", "VpnGw4AZ", "VpnGw5AZ"). The network diagram is shown below:

![1][1]

The Terraform scripts are organized into two folders:
- folder 1: it contains the files to create vnet1, vnet2, the Gateway subnet, and the VPN Gateways gw1 and gw2.
- folder 2: it contains the files to create local network gateways and VPN connections.

Deployment must be executed in sequence:
- <ins>first step</ins>: run the deployment in folder 1
- <ins>second step</ins>: once deployment in folder 1 is completed, proceeds with the deployment in folder 2

> [!NOTE] 
> Running the deployment in folder 2 first will fail because the VNets and VPN Gateways will not yet exist.

Inside the folder get-vals there are the scripts to fetch the BP peering IP address of the VPN Gateway1 and VPN Gateway2.

![2][2]

Commands to execute the deployment:

`az login --scope https://graph.microsoft.com/.default`  <br>
`az account set -s $subscriptionName`  : set the context <br>
`az account show`                      : show context information <br>

Go to the folder 1:
`terraform init -upgrade` <br>
`terraform plan -out main.tfplan` <br>
`terraform apply main.tfplan` <br>


When the deployment is successfuly completed move to the folder 2 and repeat the same commands:
`terraform init -upgrade` <br>
`terraform plan -out main.tfplan` <br>
`terraform apply main.tfplan` <br>

<br>
Powershell commands to fetch information on Site-to-Site VPN tunnels:  

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
```

## ANNEX: how to start
1. download terraform: (https://developer.hashicorp.com/terraform/install) <br>
The .zip file contains <ins>LICENSE.txt</ins> and <ins>**terraform.exe**</ins>
1. copy those files to a folder, i.e. C:\terraform
1. Update your system's global PATH environment variable to include the directory that contains the terraform executable.
In Windows the path is in the registry but usually you edit through this interface: <br>
Go to **System ->About -> Advanced system settings -> Advanced -> Environment Variables** <br>
Scroll down in system variables until you find PATH.<br>
Click NEW 
Add the path: **C:\terraform**
1. logout and login in Windows to take effect of the PATH change
1. in powershell check the path: `echo $env:path`
1. check the version by command: `terraform -version` <br>
1. to run a deployment: <br>
   `terraform init -upgrade` <br>
   `terraform plan -out main.tfplan` <br>
   `terraform apply main.tfplan` <br>

> [!NOTE]
> if you should issue with azure authetication, run: <br> `az login --scope https://graph.microsoft.com/.default`
>

<br><br>



`Tags: Site-to-site VPN, Terraform` <br>
`date: 09-01-2025` <br>

<!--Image References-->

[1]: ./media/network-diagram.png "high level network diagram"
[2]: ./media/network-diagram2.png "network diagram with Site-to-Site VPN details"

<!--Link References-->

