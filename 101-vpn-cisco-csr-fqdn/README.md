<properties
   pageTitle="VPN IPSec tunnel between two Cisco CSR 1000v in Azure"
   description="configuration to setup an IPSec tunnel between two Cisco CSR 1000v in two different Azure VNet"
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
   ms.date="17/05/2017"
   ms.author="fabferri" />
##  Configuration of VPN IPSec tunnel between two Cisco CSR 1000v in Azure

Azure market place offers a large number of Network Virtual Appliances (NVAs). In this article is reported the configuration of VPN IPSec tunnel between two Cisco 1000v deployed in different Azure Virtual Networks (VNets).

An effective way to deploy Cisco CSR 1000v is to use Azure Resource Manager (ARM) templates published in the repository [https://github.com/Azure/azure-quickstart-templates](https://github.com/Azure/azure-quickstart-templates "Azure quickstart templates").

Here a short description of the scripts:

- **azureCSR1000v.ps1**: powershell script to run the ARM template to create the NVAs. Before running the script, replace the input parameters with your values. The script contains two boolean variables to make a selection on deployment ($true to run the specific deployment, $false to skip the deployment). The script deploys two CSR 1000v in the same subscription, but it can easily modified to make the deployments in different Azure subscriptions.
- **azuredeploy.json**: JSON template to deploy a VNet, two UDRs (one for the external subnet and one internal subnet) and one Cisco 1000v. The ARM template contains only a small changes compare with the template available in the official github repository.
- **azuredeploy.parameters1.json**: parameter files used to deploy the Azure VNet1 with the first Cisco 1000v. Before starting the deployment in azure, set the values of the parameters "adminUsername"  and "adminPassword".
- **azuredeploy.parameters2.json**: parameter files required to create the second VNet with the second Cisco 1000v. Before starting the deployment in azure, set the values of the parameters "adminUsername"  and "adminPassword".
- **csr1-config.txt**: configuration of the first Cisco 1000v (left side of the network topology)
- **csr2-config.txt**: configuration of the second Cisco 1000v (right side of the network topology)


###  NETWORK TOPOLOGY
This document uses this network setup:

[![0]][0]

To configure the IPSec VPN is used the Cisco FlexVPN: "FlexVPN is Cisco’s implementation of the IKEv2 standard featuring a unified paradigm and CLI that combines site to site, remote access, hub and spoke topologies and partial meshes (spoke to spoke direct)."

## Router Configurations
#### CSR1 (Cisco CSR1000v on the left side)


    crypto ikev2 proposal azure-proposal
     encryption aes-cbc-256 aes-cbc-192 3des
     integrity sha512 sha256 md5
     group  14 5 2
    !
    crypto ikev2 policy azure-policy
     proposal azure-proposal
    !  
    crypto ikev2 keyring mykeys
    peer CSR2
     address 40.69.211.144
     pre-shared-key cisco123
    !
    crypto ikev2 profile azure-profile 
     match identity remote fqdn domain cisco.com 
     identity local fqdn CSR1.cisco.com 
     authentication local pre-share 
     authentication remote pre-share
     keyring local mykeys
    !
    crypto ipsec transform-set azure-ipsec-proposal-set esp-aes 256 esp-sha512-hmac
     mode transport
    !
    crypto ipsec profile azure-vti
     set transform-set azure-ipsec-proposal-set
     set ikev2-profile azure-profile
    !
    interface Tunnel0 
     ip address 172.16.0.1 255.255.255.252 
     tunnel source GigabitEthernet1 
     tunnel destination 40.69.211.144
     tunnel protection ipsec profile azure-vti 
    !
    crypto ikev2 dpd 10 2 on-demand
    !
    router ospf 1 
     network 10.1.1.0 255.255.255.0 area 0   
     network 172.16.0.0 255.255.255.0 area 0



#### CSR2 (Cisco CSR1000v on the right side)

    crypto ikev2 proposal azure-proposal
     encryption aes-cbc-256 aes-cbc-192 3des
     integrity sha512 sha256 md5
     group  14 5 2
    !
    crypto ikev2 policy azure-policy
     proposal azure-proposal
    !
    crypto ikev2 keyring mykeys
     peer CSR2
     address 52.164.231.103
     pre-shared-key cisco123
    !
    crypto ikev2 profile azure-profile 
     match identity remote fqdn domain cisco.com 
     identity local fqdn CSR2.cisco.com 
     authentication local pre-share
     authentication remote pre-share
     keyring local mykeys 
    ! 
    crypto ipsec transform-set azure-ipsec-proposal-set esp-aes 256 esp-sha512-hmac
     mode transport
    !
    crypto ipsec profile azure-vti
     set transform-set azure-ipsec-proposal-set
     set ikev2-profile azure-profile
    !
    interface Tunnel0 
     ip address 172.16.0.2 255.255.255.252 
     tunnel source GigabitEthernet1 
     tunnel destination 52.164.231.103 
     tunnel protection ipsec profile azure-vti
    ! 
    crypto ikev2 dpd 10 2 on-demand
    ! 
    router ospf 1 
     network 10.2.1.0 255.255.255.0 area 0 
     network 172.16.0.0 255.255.255.0 area 0 


 <span style="color:darkblue">**IPSec Cisco CSR 1000v configuration schema**</span>
[![1]][1]



#### How to verify the configuration

In order to verify the configuration use few show commands:

-  **show crypto session**
- **show crypto session detail**
- **show crypto ikev2 sa**
- **show crypto ikev2 session detail**
- **show crypto ipsec sa**


<!--Image References-->
[0]: ./media/NetworkTopology.png "Network topology" 
[1]: ./media/RouterConfigs.png "Router configurations"

<!--Link References-->



