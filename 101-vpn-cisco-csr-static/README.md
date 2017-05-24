<properties
   pageTitle="VPN IPSec tunnel between two Cisco CSR 1000v in Azure with static routing"
   description="configuration of a VPN IPSec tunnel between two Cisco CSR 1000v in two different Azure VNets with static routing and NAT"
   services=""
   documentationCenter="na"
   authors="fabferri"
   manager=""
   editor=""/>

<tags
   ms.service="Configuration-Example-Azure"
   ms.devlang="na"
   ms.topic="article"
   ms.tgt_pltfrm="na"
   ms.workload="na"
   ms.date="21/05/2017"
   ms.author="fabferri" />
##  VPN IPSec tunnel between two Cisco CSR 1000v in Azure with static routing

The article reports the scripts and Azure templates to create two Azure Virtual Networks (VNets) each with a Cisco CSR 1000v and a CentOS Virtual Machine (VM). The two VNets are interconnected through an IPSec tunnel established between the two CSR 1000v. A VM is attached to the inside subnet of every vnet. A NAT overload is configured on the CSR 1000V to allow to the VM to reach out destination in internet.

Snippet of the scripts:

- **01-azure-csr1000v.ps1**: it is the script to start the deployment of VNets and Cisco CSR 1000v. Before running the script, set the name of Azure subscription ID where you want to make the deployment. This script needs to run before **02-azure-vms.ps1**
- **azuredeploy.json**: JSON template to deploy a VNet, two UDRs (one for the external subnet and one internal subnet) and one Cisco 1000v. Before running the powershell script to deploy your ARM template, customize your values in the parameter files **azuredeploy.parameters1.json** and **azuredeploy.parameters2.json**
- **azuredeploy.parameters1.json**: parameter files used to deploy the Azure VNet1 with the first Cisco 1000v. Before starting the deployment in azure, set your custom values in the parameters "adminUsername"  and "adminPassword". 
- **azuredeploy.parameters2.json**: parameter files required to create the second VNet with the second Cisco 1000v. Before starting the deployment in azure, set your custom values in the parameters "adminUsername"  and "adminPassword".
- **02-azure-vms.ps1**: the script run a development of two VMs attached to different VNet. Run the script only after complete the setup of the two VNets.
- **azure-vm.json**: Azure template to create CentOS VM attached to an existing VNet.
- **azure-vm1.parameters.json**: template parameter file to create the first Azure VM. Before running the script set the system username and password of the Azure VM.
- **azure-vm2.parameters.json**: template parameter file to create the second Azure VM. Before running the script set the system username and password of the Azure VM.
- **csr1-config-static.txt**: configuration of the first Cisco 1000v (left side of the network topology)
- **csr2-config-static.txt**: configuration of the second Cisco 1000v (right side of the network topology)


###  NETWORK TOPOLOGY
Here the network topology in use in the setup:

[![0]][0]

The configuration is based on Virtual Tunnel Interfaces (VTIs); the network diagram reports the termination of IPSec tunnel on the VTIs.
The two interface tunnels (tunnel0 in CSR1 and tunnel0 in CSR2) are reachable through static routing.

[![1]][1]

The CentOS VMs are able to access to internet through the transit in CSR 1000v, that apply a NAT overload using the egress interface gigabitEthernet1.
When configuring a site-to-site VPN tunnel, it is imperative to instruct the router not to perform NAT (deny NAT) on packets destined to the remote VPN networks. This is easily done by inserting a deny statement at the ***beginning*** of the NAT access lists:

##### CSR1
    ip access-list extended NAT 
     deny   ip 10.1.0.0 0.0.255.255 10.2.0.0 0.0.255.255
     deny   ip host 172.16.0.1 host 172.16.0.2
     permit ip 10.1.1.0 0.0.0.255 any

##### CSR2
    ip access-list extended NAT 
     deny   ip 10.2.0.0 0.0.255.255 10.1.0.0 0.0.255.255
     deny   ip host 172.16.0.2 host 172.16.0.1
     permit ip 10.2.1.0 0.0.0.255 any




## Router Configurations
####  <span style="color:darkblue">CSR1 (Cisco CSR1000v on the left side)</span>


    crypto ikev2 proposal AZURE-PROPOSAL
     encryption aes-cbc-256 aes-cbc-128 3des
     integrity sha1
     group 2
    !
    crypto ikev2 policy AZURE-POLICY
     proposal AZURE-PROPOSAL
    !  
    crypto ikev2 keyring mykeys
     peer CSR2
      ! CSR2-public IP address of the remote peer
      address 13.94.106.240
      pre-shared-key  CSRcisco123
    !
    crypto ikev2 profile AZURE-PROFILE
     match address local interface GigabitEthernet1
     ! private IP address of the remote egress interface in CSR2
     match identity remote address 10.2.0.4 255.255.255.255
     authentication local pre-share 
     authentication remote pre-share
     keyring local mykeys
    !
    !
    crypto ipsec transform-set AZURE-IPSEC-PROPOSAL-SET esp-aes 256 esp-sha-hmac
     mode transport
    !
    crypto ipsec profile AZURE-VTI
     set transform-set AZURE-IPSEC-PROPOSAL-SET
     set ikev2-profile AZURE-PROFILE
    !
    interface Loopback0
     ip address 172.16.0.1 255.255.255.252 
    !
    interface Tunnel0 
     ip unnumbered Loopback0
     ip tcp adjust-mss 1350
     tunnel source GigabitEthernet1
     ! CSR2-public IP address of the remote peer
     tunnel destination 13.94.106.240
     tunnel protection ipsec profile AZURE-VTI
     exit
    !
    crypto ikev2 dpd 10 2 on-demand
    !
    ip route 10.2.0.0 255.255.0.0 tunnel0
    ip route 172.16.0.2 255.255.255.255 tunnel0
    !
    !
    interface gigabitethernet 2
     ip nat inside
    interface gigabitethernet 1
     ip nat outside
    !
    ip access-list extended NAT 
     deny   ip 10.1.0.0 0.0.255.255 10.2.0.0 0.0.255.255
     deny   ip host 172.16.0.1 host 172.16.0.2
     permit ip 10.1.1.0 0.0.0.255 any
    !
    ip nat inside source list NAT interface gigabitethernet 1 overload 


#### <span style="color:darkblue">CSR2 (Cisco CSR1000v on the right side)</span>

    crypto ikev2 proposal AZURE-PROPOSAL
     encryption aes-cbc-256 aes-cbc-128 3des
     integrity sha1
     group 2
    !
    crypto ikev2 policy AZURE-POLICY
     proposal AZURE-PROPOSAL 
    !
    crypto ikev2 keyring mykeys
     peer CSR1
     ! CSR1-public IP address of the remote peer
     address 13.79.170.51
     pre-shared-key CSRcisco123
    !
    crypto ikev2 profile AZURE-PROFILE 
     match address local interface GigabitEthernet1
     match identity remote address 10.1.0.4 255.255.255.255
     authentication local pre-share
     authentication remote pre-share
     keyring local mykeys
    ! 
    crypto ipsec transform-set AZURE-IPSEC-PROPOSAL-SET esp-aes 256 esp-sha-hmac
     mode transport
    !
    crypto ipsec profile AZURE-VTI
     set transform-set AZURE-IPSEC-PROPOSAL-SET
     set ikev2-profile AZURE-PROFILE
    !
    interface Loopback0
     ip address 172.16.0.2 255.255.255.252 
    !
    interface Tunnel0 
     ip unnumbered Loopback0 
     ip tcp adjust-mss 1350
     tunnel source GigabitEthernet1 
     ! CSR1-public IP address of the remote peer
     tunnel destination 13.79.170.51
     tunnel protection ipsec profile AZURE-VTI
    ! 
    crypto ikev2 dpd 10 2 on-demand
    ! 
    ip route 10.1.0.0 255.255.0.0 tunnel0
    ip route 172.16.0.1 255.255.255.255 tunnel0
    !
    !
    !
    interface gigabitethernet 2
     ip nat inside
    !
    interface gigabitethernet 1
     ip nat outside
    !
    ip access-list extended NAT 
     deny   ip 10.2.0.0 0.0.255.255 10.1.0.0 0.0.255.255
     deny   ip host 172.16.0.2 host 172.16.0.1
     permit ip 10.2.1.0 0.0.0.255 any
    !
    ip nat inside source list NAT interface gigabitethernet 1 overload 


### How to verify the configuration

In order to verify the configuration use few show commands:

- **show ip interface brief**
- **show crypto session**
- **show crypto session detail**
- **show crypto ikev2 sa**
- **show crypto ikev2 session detail**
- **show crypto ipsec sa**
- **show ip route**

To check the NAT table:

- **show ip nat translations**
- **show ip nat statistics**

To clean up the NAT translation:

- clear ip nat translation * 


<!--Image References-->
[0]: ./media/network-diagram.png "Network Diagram" 
[1]: ./media/ipsec-tunnel.png "IPSec tunnel"

<!--Link References-->



