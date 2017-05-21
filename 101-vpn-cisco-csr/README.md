<properties
   pageTitle="VPN IPSec tunnel between two Cisco 1000v in Azure"
   description="configuration of a VPN IPSec tunnel between two Cisco 1000v in two different Azure VNets"
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
##  VPN IPSec tunnel between two Cisco 1000v in Azure

Azure market place offers a large number of Network Virtual Appliances. Here is reported the configuration of VPN IPSec tunnel between two Cisco 1000v deployed in different Azure Virtual Networks (VNets).

An effective way to deploy Cisco CSR1000v is through Azure Resource Manager (ARM) templates published in the repository [https://github.com/Azure/azure-quickstart-templates](https://github.com/Azure/azure-quickstart-templates "Azure quickstart templates"). The article use an Azure template that creates 

- a VNet with two virtual subnets, internal subnet and external subnet 
- one Cisco CSR1000v with two Virtual Network Interface Cards (NICs)
- two UDRs (User-Defined Routes). The UDRs force the traffic from/to subnets to transit through the Cisco CSR
- a Network Security Group (NSG). The NSG can be applied to the egress interface of the Cisco CSR to filter the incoming traffic. 

The following example shows how to configure VPN IPsec using the preshared key authentication method between two **V**irtual **T**unnel **I**nterfaces (VTI) in IKEv2.
Here a short description of the scripts:

- **azure-csr1000v.ps1**: powershell script to run the ARM template to create the NVAs. Before running the script, replace the input parameters with your values. The script contains two boolean variables to make a selection on deployment (**$true** to create the specific deployment, **$false** to skip the deployment). The script deploys two CSR 1000v in the same subscription but it can be easily modified to make the deployments in different Azure subscriptions.
- **azuredeploy.json**: JSON template to deploy a VNet, two UDRs (one for the external subnet and one internal subnet) and one Cisco 1000v. The Azure template contains only small changes compare with the template available in the official github repository. Before running the powershell script to deploy your ARM template, customize your values in the parameter files **azuredeploy.parameters1.json** and **azuredeploy.parameters2.json**
- **azuredeploy.parameters1.json**: parameter files used to deploy the Azure VNet1 with the first Cisco 1000v. Before starting the deployment in azure, set your custom values in the parameters "adminUsername"  and "adminPassword". 
- **azuredeploy.parameters2.json**: parameter files required to create the second VNet with the second Cisco 1000v. Before starting the deployment in azure, set your custom values in the parameters "adminUsername"  and "adminPassword".
- **csr1-config**: configuration of the first Cisco 1000v (left side of the network topology)
- **csr2-config.txt**: configuration of the second Cisco 1000v (right side of the network topology)


###  NETWORK TOPOLOGY
Configuration of the IPSec VPN is done through Cisco FlexVPN: "FlexVPN is Cisco’s implementation of the IKEv2 standard featuring a unified paradigm and CLI that combines site to site, remote access, hub and spoke topologies and partial meshes (spoke to spoke direct)."
Here the network topology in use in the setup:

[![0]][0]

The configuration use the Virtual Tunnel Interface (VTI); the network diagram reports the termination of IPSec tunnel to the VTI.

[![1]][1]

## Router Configurations
####  <span style="color:darkblue">CSR1 (Cisco CSR1000v on the left side)</span>

    interface gigabitEthernet 2
     ip address dhcp
    !
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
      address 52.232.43.254
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
     tunnel source GigabitEthernet1
     ! CSR2-public IP address of the remote peer
     tunnel destination 52.232.43.254
     tunnel protection ipsec profile AZURE-VTI 
    !
    crypto ikev2 dpd 10 2 on-demand
    !
    router ospf 1 
     network 10.1.1.0 255.255.255.0 area 0   
     network 172.16.0.0 255.255.255.0 area 0


#### <span style="color:darkblue">CSR2 (Cisco CSR1000v on the right side)</span>

    interface gigabitEthernet 2
     ip address dhcp
    !
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
     address 52.169.203.146
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
    interface Tunnel0 
     ip unnumbered Loopback0 
     tunnel source GigabitEthernet1 
     ! CSR1-public IP address of the remote peer
     tunnel destination 52.169.203.146
     tunnel protection ipsec profile AZURE-VTI
    ! 
    crypto ikev2 dpd 10 2 on-demand
    ! 
    router ospf 1 
     network 10.2.1.0 255.255.255.0 area 0 
     network 172.16.0.0 255.255.255.0 area 0


### Note 1 ###

The command: 

crypto ikev2 dpd *interval* *retry-interval* on-demand

verifies if IKE is live on the peer, by sending keepalive before sending data.

### Note 2 ###
In the IKEv2 keyring, Defining the peer enters IKEv2 keyring peer configuration mode **Router(config-ikev2-keyring-peer)#** 

The address command specifies an IPv4 address (or range) for the peer:

Router(config-ikev2-keyring-peer)# address *ipv4-address* *Mask*

this IP address is the IKE endpoint address and it is independent of the identity address. 

### How to verify the configuration

In order to verify the configuration use few show commands:

- **show ip interface brief**
- **show crypto session**
- **show crypto session detail**
- **show crypto ikev2 sa**
- **show crypto ikev2 session detail**
- **show crypto ipsec sa**
- **show ip route**

### ANNEX: IKEv2 in Cisco Easy VPN
As described in Cisco documentation, IKEv2 protocol in Cisco IOS software is based on following constructs:

- **IKEv2 Proposal** (required). An IKEv2 proposal is a collection of transforms used in the negotiation of IKE SAs as part of the IKE_SA_INIT exchange. The transform types used in the negotiation are as follows:
	- Encryption algorithm
	- Integrity algorithm
	- Pseudo-Random Function (PRF) algorithm
	- Diffie-Hellman (DH) group

IKEv2 proposals are named and not numbered during the configuration. Manually configured IKEv2 proposals must be linked with an **IKEv2 policy**; otherwise, the proposals are not used in the negotiation.
Multiple transforms can be configured and proposed by the initiator for encryption, integrity, and group, of which one transform is selected by the responder. When multiple transforms are configured for a transform type, the order of priority is from left to right.

- **IKEv2 Policy** (required). You must configure at least one encryption algorithm, one integrity algorithm, and one DH group for the proposal to be considered complete. An IKEv2 policy contains proposals that are used to negotiate the encryption, integrity, PRF algorithms, and DH group in SA_INIT exchange. It can have match statements which are used as selection criteria to select a policy during negotiation.
- **IKEv2 Profile** (required). An IKEv2 profile is a repository of the nonnegotiable parameters of the IKE SA, such as local or remote identities and authentication methods and the services that are available to the authenticated peers that match the profile.An IKEv2 profile must be attached to either crypto map or IPSec profile on both IKEv2 initiator and responder.
- **IKEv2 Keyring** (required). An IKEv2 keyring is a repository of symmetric and asymmetric preshared keys. The IKEv2 keyring is associated with an IKEv2 profile and hence, caters to a set of peers that match the IKEv2 profile. The IKEv2 keyring gets its VRF context from the associated IKEv2 profile.

### REFERENCE
[http://www.cisco.com/c/en/us/td/docs/ios/sec_secure_connectivity/configuration/guide/convert/sec_ike_for_ipsec_vpns_15_1_book/sec_cfg_ikev2.html](http://www.cisco.com/c/en/us/td/docs/ios/sec_secure_connectivity/configuration/guide/convert/sec_ike_for_ipsec_vpns_15_1_book/sec_cfg_ikev2.html "Internet Key Exchange for IPsec VPNs Configuration Guide")

<!--Image References-->
[0]: ./media/network-diagram.png "Network Diagram" 
[1]: ./media/ipsec-tunnel.png "IPSec tunnel"

<!--Link References-->



