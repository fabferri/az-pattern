<properties
pageTitle= 'hub-spoke vnets with Route Server in hub and in the spoke vnets and centralized routing control through NVA' 
description= "hub-spoke vnets with Route Server in hub and in the spoke vnets and centralized routing control through NVA"
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
   ms.workload="Route Server, Azure vnet peering, ExpressRoute"
   ms.date="16/02/2023"
   ms.review=""
   ms.author="fabferri" />

# hub-spoke vnets with Route Server in hub and in the spoke vnets and centralized routing control through NVA

## Caveat: the configuration is for testing ONLY. 

The article describes a scenario with hub-spoke vnets in peering and a connection with on-premises through ExpressRoute circuit. The high-level network diagram is shown below:

[![1]][1]

The configuration has the following intents: 
- the communications spoke-to-spoke vnet are not allowed
- the communication between each spoke vnet and on-premises through the ExpressRoute circuit is allowed
- address space assigned to hub and spoke vnets are minor networks belonging to the network 10.0.0.0/8
- the customer's edge routers advertise to the ExpressRoute circuit the major network 10.0.0.0/8
- the traffic between spoke vnets to on-premises does <ins>not</ins> transit through the nva1 in the hub
- routing in spoke vnets is controlled by nva1 in the hub
- each spoke vnet can breakout in internet through an NVA (or Azure firewall) in fw vnet
- the configuration does not use UDRs

<br>

In architectures hub-spoke vnet, the spoke vnets do not communicate each other because **vnet peering does not have the transitive routing property**. Nevertheless, in presence of ExpressRoute Gateway and connection with ExpressRoute circuit, the routing can change. When customer's edge routers advertise to the ExpressRoute circuit a major network, i.e. 10.0.0.0/8, and the spoke vnets have minor networks in the range of major network 10/8, the communication spoke-to-spoke will allow with transit through the MSEE routers (hairpinning transit). The routing behaviour described happens only if the customer's edge routers advertise to the ExpressRoute circuit the major network. <br>
This post aims to find out a solution to avoid the spoke-to-spoke communication in hairpinning with transit through the MSEE routers.  

### NOTE:
#### In the full diagrams below two different NVAs, SEA-Cust33-csr1 and SEA-Cust33-nva1, are deployed in the hub vnet:
#### - SEA-Cust33-csr1 runs with Cisco CSR
#### - SEA-Cust33-nva1 runs in Ubuntu 22.04 with FRR
#### In testing only one NVA should active, at one time. The present post reports the configuration for both (cisco CSR and FRR)
#### In the discussion the active NVA in the hub is referred as **nva1**

<br>
The full diagram with eBGP sessions between Route Server and Cisco CSR in the hub vnet:

[![2]][2]

<br>

The full diagram with eBGP sessions between Route Server and FRR in the hub vnet:

[![3]][3]

<br>

Let's discuss briefly the configuration details:
- the vnet peering in spoke side are created with the following attributes: <br>
   - "allowVirtualNetworkAccess": true, 
   - "allowForwardedTraffic": true,     
   - **"allowGatewayTransit": false,**   
   - **"useRemoteGateways": false,**    
In present setting, the address space of spoke vnets are not sent from the ExpressRoute Gateway to the ExpressRoute circuit. A different mechanism is used to advertise the address space of spoke vnets to on-premises. 
- the configuration does not use UDRs in the hub neither in spoke vnets
- each Route Server has a fix ASN: 655515 that it can't be changed. 
- two eBGP session are established between **nva1** and the route server deployed in each spoke vnet
- two eBGP session are created between the **nva1** and the route server **rs1** in the hub vnet
- the **nva1** in hub vnet requires the following BGP configuration:
   - **nva1** applies **AS-override** in all eBGP peering with Route Servers. This is required to avoid discard of IP network prefixes in the Route Servers. _[In eBGP session, AS loop detection is done by scanning the full AS path (as specified in the AS_PATH attribute), and checking that the autonomous system number of the local system does not appear in the AS path]_
   - **nva1** set **next-hop unchanged** in all BGP peers, to avoid transit of the data path through the **nva1** 
   - **nva1** applies filtering in BGP advertisements inbound and outbound by route-map. 
   - **nva1** advertises to the spokes the major network of all spoke vnets. In the present configuration the major network for the three spoke vnets is 10.0.4.0/22.
- the on-premises major network 10.0.0.0/8 is advertised from the **nva1** to each Route Server in spoke vnet
- To block the hairpinning transit through the MSEE routers two actions are required:
   - **nva1** advertises to the spoke Route Server the major network of all spoke vnets. In the present configuration the major network for the three spoke vnets is 10.0.4.0/22 with next-hop the IP address of **nva1**. Having the major network 10.0.4.0/22 in the spoke vnet, it will take the precedence over the on-premises network 10.0.0.0/8 becasue the network 10.0.4.0/22 is more specific than 10.0.0.0/8
   - **nva1** has an inbound ACL to deny all the traffic inter-spoke
- **nva1** advertise the default route 0.0.0.0/0 with next-hop: IP FW, only to the Route Server in spoke vnets  

### Pro and cons of the configuration
- **Pro**. The data path between spoke vnets and the on-premises network does not transit through the NVA. This is an advantage because for intensive traffic between spoke vnets and on-premises networks NVA won't be a bottleneck. NVA can run on small/medium VM SKUs becasue it is responsible only to manage the BGP.
- **Pro**.The configuration discussed in this post pursues a different approach, because the NVA in hub vnet controls the spoke vnets routing. Centralization of control plane in NVA has the advantage to provide a unique point of control.
- **Pro**. The design discussed does not requires UDRs and isolation between spoke vnets does not requires a presence of firewall/NVA in the hub.
- **Pro**. The spoke vnets breakouts in internet with transit through a specific DMZ vnet, where security to/from internet can be controlled by firewall/NVA.  
- **Cons**. The architecture described is an uncommon design pattern. In common design patterns the spoke vnets routing are controlled by UDRs and transit through NVA/firewall. 
- **Cons**. The architecture discussed in the article has not been tested out at scale (large number of spoke vnets and large number of VMs in spoke vnets)   
- **Cons**. A potential BGP misconfiguration in the NVA in the hub can cause a total routing failure in all the spoke vnets.



## <a name="list of files"></a>1. Project files

| File name                 | Description                                                                        |
| ------------------------- | ---------------------------------------------------------------------------------- |
| **01-vnet-vms.json**      | ARM template to deploy spoke vnets, hub vnet, and VMs  in the hub ans spoke vnets  |
| **01-vnet-vms.ps1**       | powershell script to run **01-vnet-vms.json**                                      |
| **02-rs.json**            | ARM template to deploy Route Serves in spoke vnets and hub vnet and create the BGP connections |
| **02-rs.jps1**            | powershell script to run **02-rs.json**                                            |
| **03-er-conn-vnet1.json** | Create the ExpressRoute connection between the hub vnet and the ExpressRoute circuit|
| **03-er-conn-vnet1.ps1**  | powershell script to run **03-er-conn-vnet1.json**                                 |
| **04-csr.json**           | Create a Cisco CSR in the hub vnet                                                 |
| **04-csr.ps1**            | powershell script to run **04-csr.json**                                           |
| **csr-images.ps1**        | powershell to approve terms and condition to use Cisco CSR from Azure markeplace   |
| **csr-config.txt**        | Cisco CSR configuration |
| **frr-config.txt**        | FRR configuration       |

Before running the powershell scripts, customize the values of input variables:
```powershell
$adminUsername = 'ADMINISTRATOR_USERNAME'
$adminPassword = 'ADMNISTRATOR_PASSWORD'
$subscriptionName = 'AZURE_SUBSCRIPTION_NAME'
$deploymentName = 'DEPLOYMENT_NAME'
$location = 'AZURE_REGION_NAME'   
$rgName = 'RESOURCE_GROUP_NAME'
```

<br>


## <a name="Cisco CSR configuration in the hub vnet"></a>2. Cisco CSR configuration in the hub vnet
Here a main snippet of Cisco CSR **SEA-Cust33-csr1** configuration:

```console
!
interface GigabitEthernet1
 ip address dhcp
 ip nat outside
 negotiation auto
 no mop enabled
 no mop sysid
!
interface GigabitEthernet2
 ip address dhcp
 ip access-group DENYINTERSP in
 negotiation auto
 no mop enabled
 no mop sysid
!
router bgp 65001
 bgp log-neighbor-changes
 neighbor 10.0.4.4 remote-as 65515
 neighbor 10.0.4.4 ebgp-multihop 5
 neighbor 10.0.4.4 timers 60 180
 neighbor 10.0.4.5 remote-as 65515
 neighbor 10.0.4.5 ebgp-multihop 5
 neighbor 10.0.4.5 timers 60 180
 neighbor 10.0.5.4 remote-as 65515
 neighbor 10.0.5.4 ebgp-multihop 5
 neighbor 10.0.5.4 timers 60 180
 neighbor 10.0.5.5 remote-as 65515
 neighbor 10.0.5.5 ebgp-multihop 5
 neighbor 10.0.5.5 timers 60 180
 neighbor 10.0.6.4 remote-as 65515
 neighbor 10.0.6.4 ebgp-multihop 5
 neighbor 10.0.6.4 timers 60 180
 neighbor 10.0.6.5 remote-as 65515
 neighbor 10.0.6.5 ebgp-multihop 5
 neighbor 10.0.6.5 timers 60 180
 neighbor 10.17.33.68 remote-as 65515
 neighbor 10.17.33.68 ebgp-multihop 5
 neighbor 10.17.33.68 timers 60 180
 neighbor 10.17.33.69 remote-as 65515
 neighbor 10.17.33.69 ebgp-multihop 5
 neighbor 10.17.33.69 timers 60 180
 !
 address-family ipv4
  network 0.0.0.0
  aggregate-address 10.0.4.0 255.255.252.0
  neighbor 10.0.4.4 activate
  neighbor 10.0.4.4 as-override
  neighbor 10.0.4.4 soft-reconfiguration inbound
  neighbor 10.0.4.4 route-map SPIN in
  neighbor 10.0.4.4 route-map SPOUT out
  neighbor 10.0.4.5 activate
  neighbor 10.0.4.5 as-override
  neighbor 10.0.4.5 soft-reconfiguration inbound
  neighbor 10.0.4.5 route-map SPIN in
  neighbor 10.0.4.5 route-map SPOUT out
  neighbor 10.0.5.4 activate
  neighbor 10.0.5.4 as-override
  neighbor 10.0.5.4 soft-reconfiguration inbound
  neighbor 10.0.5.4 route-map SPIN in
  neighbor 10.0.5.4 route-map SPOUT out
  neighbor 10.0.5.5 activate
  neighbor 10.0.5.5 as-override
  neighbor 10.0.5.5 soft-reconfiguration inbound
  neighbor 10.0.5.5 route-map SPIN in
  neighbor 10.0.5.5 route-map SPOUT out
  neighbor 10.0.6.4 activate
  neighbor 10.0.6.4 as-override
  neighbor 10.0.6.4 soft-reconfiguration inbound
  neighbor 10.0.6.4 route-map SPIN in
  neighbor 10.0.6.4 route-map SPOUT out
  neighbor 10.0.6.5 activate
  neighbor 10.0.6.5 as-override
  neighbor 10.0.6.5 soft-reconfiguration inbound
  neighbor 10.0.6.5 route-map SPIN in
  neighbor 10.0.6.5 route-map SPOUT out
  neighbor 10.17.33.68 activate
  neighbor 10.17.33.68 as-override
  neighbor 10.17.33.68 soft-reconfiguration inbound
  neighbor 10.17.33.68 route-map RSIN in
  neighbor 10.17.33.68 route-map RSOUT out
  neighbor 10.17.33.69 activate
  neighbor 10.17.33.69 as-override
  neighbor 10.17.33.69 soft-reconfiguration inbound
  neighbor 10.17.33.69 route-map RSIN in
  neighbor 10.17.33.69 route-map RSOUT out
 exit-address-family
!
ip route 0.0.0.0 0.0.0.0 10.17.33.17
ip route 10.0.4.4 255.255.255.255 10.17.33.1
ip route 10.0.4.5 255.255.255.255 10.17.33.1
ip route 10.0.5.4 255.255.255.255 10.17.33.1
ip route 10.0.5.5 255.255.255.255 10.17.33.1
ip route 10.0.6.4 255.255.255.255 10.17.33.1
ip route 10.0.6.5 255.255.255.255 10.17.33.1
ip route 10.17.33.68 255.255.255.255 10.17.33.1
ip route 10.17.33.69 255.255.255.255 10.17.33.1
!
ip access-list extended BUF-FILTER
 10 permit ip 10.0.4.0 0.0.0.255 any
 20 permit ip 10.0.5.0 0.0.0.255 any
 30 permit ip 10.0.6.0 0.0.0.255 any
ip access-list extended DENYINTERSP
 5 permit tcp any eq bgp any
 10 deny   ip 10.0.4.0 0.0.3.255 10.0.4.0 0.0.3.255
 50 permit ip any any
 60 permit icmp any any
!
ip prefix-list DEFFW seq 10 permit 0.0.0.0/0
!
ip prefix-list HUB-VNET seq 10 deny 10.17.33.0/24
!
ip prefix-list ONPREM seq 10 permit 10.0.0.0/8
!
ip prefix-list SPMAJOR seq 10 permit 10.0.4.0/22
!
ip prefix-list SPOKE-VNET seq 10 deny 10.0.4.0/24
ip prefix-list SPOKE-VNET seq 20 deny 10.0.5.0/24
ip prefix-list SPOKE-VNET seq 30 deny 10.0.6.0/24
ip prefix-list SPOKE-VNET seq 50 permit 10.0.0.0/8
ip prefix-list SPOKE-VNET seq 60 permit 10.0.4.0/22
!
!
route-map SPIN permit 20
!
route-map RSIN permit 20
 match ip address prefix-list ONPREM
!
route-map FW permit 10
 match ip address prefix-list DEFFW
 set ip next-hop 10.100.0.10
!
route-map SPOUT permit 20
 match ip address prefix-list SPOKE-VNET
 set ip next-hop unchanged
!
route-map SPOUT permit 30
 match ip address prefix-list DEFFW
 set ip next-hop 10.100.0.10
!
route-map RSOUT deny 5
 match ip address prefix-list DEFFW
!
route-map RSOUT deny 6
 match ip address prefix-list SPMAJOR
!
route-map RSOUT permit 10
 set ip next-hop unchanged
!
line con 0
 stopbits 1
line aux 0
 stopbits 1
line vty 0 4
 exec-timeout 20 0
 transport input ssh
line vty 5 20
 transport input ssh
```

- **route-map SPIN**: applies a filter to the BGP advertisements received from the spoke vnets
- **route-map SPOUT**: applies a filter to the BGP advertisements sent to the spoke vnets
- **route-map SPIN**: applies a filter to the BGP advertisements received from the route server in hub vnet
- **route-map SPOUT**: applies a filter to the BGP advertisements sent to the the route server in hub vnet
- BGP Timers in Route Server are fixed: **Keep-alive** timer is set to 60 seconds and the **Hold-down** timer 180 seconds. 

BGP filtering applied to **nva1** is shown in the diagram:

[![4]][4]

## <a name="nva1 configurations"></a>3. FRR configuration
Enable IP forwarding:
```bash
sed -i -e '$a\net.ipv4.ip_forward = 1' /etc/sysctl.conf
# to apply the change
sysctl -p
# check the change
sysctl net.ipv4.ip_forward
```

In nva1 can be installed the FRR; steps to install FRR in Ubuntu are available [FRR Debian repository](https://deb.frrouting.org/)

```bash
# download the OpenPGP key for the APT repository
# the key should be downloaded over HTTPS to a location only writable by root, i.e. /usr/share/keyrings
curl -s https://deb.frrouting.org/frr/keys.asc |  gpg --dearmor > /usr/share/keyrings/frr.gpg

# possible values for FRRVER: frr-6 frr-7 frr-8 frr-stable
# frr-stable will be the latest official stable release
# Add the repository sources.list entry
FRRVER="frr-stable"
echo deb [arch=amd64 signed-by=/usr/share/keyrings/frr.gpg] https://deb.frrouting.org/frr $(lsb_release -s -c) $FRRVER | sudo tee -a /etc/apt/sources.list.d/frr.list

# update and install FRR
sudo apt update 
sudo apt install frr frr-pythontools
```

```bash
# enable bgp daemon
sed -i -e 's/^bgpd=no/bgpd=yes/' /etc/frr/daemons
# restart FRR
systemctl restart frr
# check FRR status
systemctl status frr
```
 
In FFR to access to the command line interface run the shell command:  **vtysh** <br>
The file **/etc/frr/vtysh.conf** provides configuration information for the **vtysh** command tool:
```
service integrated-vtysh-config
```
FFR configuration:
```console
SEA-Cust33-nva1# show run
Building configuration...

Current configuration:
!
frr version 8.4.2
frr defaults traditional
hostname SEA-Cust33-nva1
log syslog informational
no ipv6 forwarding
service integrated-vtysh-config
!
ip route 0.0.0.0/0 10.17.33.1
ip route 10.0.4.4/32 10.17.33.1
ip route 10.0.4.5/32 10.17.33.1
ip route 10.0.5.4/32 10.17.33.1
ip route 10.0.5.5/32 10.17.33.1
ip route 10.0.6.4/32 10.17.33.1
ip route 10.0.6.5/32 10.17.33.1
ip route 10.17.33.68/32 10.17.33.1
ip route 10.17.33.69/32 10.17.33.1
!
router bgp 65001
 bgp router-id 10.17.33.10
 neighbor 10.0.4.4 remote-as 65515
 neighbor 10.0.4.4 ebgp-multihop 3
 neighbor 10.0.4.4 timers 60 180
 neighbor 10.0.4.5 remote-as 65515
 neighbor 10.0.4.5 ebgp-multihop 3
 neighbor 10.0.4.5 timers 60 180
 neighbor 10.0.5.4 remote-as 65515
 neighbor 10.0.5.4 ebgp-multihop 3
 neighbor 10.0.5.4 timers 60 180
 neighbor 10.0.5.5 remote-as 65515
 neighbor 10.0.5.5 ebgp-multihop 3
 neighbor 10.0.5.5 timers 60 180
 neighbor 10.0.6.4 remote-as 65515
 neighbor 10.0.6.4 ebgp-multihop 3
 neighbor 10.0.6.4 timers 60 180
 neighbor 10.0.6.5 remote-as 65515
 neighbor 10.0.6.5 ebgp-multihop 3
 neighbor 10.0.6.5 timers 60 180
 neighbor 10.17.33.68 remote-as 65515
 neighbor 10.17.33.68 ebgp-multihop 3
 neighbor 10.17.33.68 timers 60 180
 neighbor 10.17.33.69 remote-as 65515
 neighbor 10.17.33.69 ebgp-multihop 3
 neighbor 10.17.33.69 timers 60 180
 !
 address-family ipv4 unicast
  network 0.0.0.0/0
  aggregate-address 10.0.4.0/22
  neighbor 10.0.4.4 as-override
  neighbor 10.0.4.4 soft-reconfiguration inbound
  neighbor 10.0.4.4 route-map SPIN in
  neighbor 10.0.4.4 route-map SPOUT out
  neighbor 10.0.4.5 as-override
  neighbor 10.0.4.5 soft-reconfiguration inbound
  neighbor 10.0.4.5 route-map SPIN in
  neighbor 10.0.4.5 route-map SPOUT out
  neighbor 10.0.5.4 as-override
  neighbor 10.0.5.4 soft-reconfiguration inbound
  neighbor 10.0.5.4 route-map SPIN in
  neighbor 10.0.5.4 route-map SPOUT out
  neighbor 10.0.5.5 as-override
  neighbor 10.0.5.5 soft-reconfiguration inbound
  neighbor 10.0.5.5 route-map SPIN in
  neighbor 10.0.5.5 route-map SPOUT out
  neighbor 10.0.6.4 as-override
  neighbor 10.0.6.4 soft-reconfiguration inbound
  neighbor 10.0.6.4 route-map SPIN in
  neighbor 10.0.6.4 route-map SPOUT out
  neighbor 10.0.6.5 as-override
  neighbor 10.0.6.5 soft-reconfiguration inbound
  neighbor 10.0.6.5 route-map SPIN in
  neighbor 10.0.6.5 route-map SPOUT out
  neighbor 10.17.33.68 as-override
  neighbor 10.17.33.68 soft-reconfiguration inbound
  neighbor 10.17.33.68 route-map RSIN in
  neighbor 10.17.33.68 route-map RSOUT out
  neighbor 10.17.33.69 as-override
  neighbor 10.17.33.69 soft-reconfiguration inbound
  neighbor 10.17.33.69 route-map RSIN in
  neighbor 10.17.33.69 route-map RSOUT out
 exit-address-family
exit
!
ip prefix-list DEFFW seq 10 permit 0.0.0.0/0
ip prefix-list HUB-VNET seq 10 deny 10.17.33.0/24
ip prefix-list ONPREM seq 10 permit 10.0.0.0/8
ip prefix-list SPMAJOR seq 10 permit 10.0.4.0/22
ip prefix-list SPOKE-VNET seq 10 deny 10.0.4.0/24
ip prefix-list SPOKE-VNET seq 20 deny 10.0.5.0/24
ip prefix-list SPOKE-VNET seq 30 deny 10.0.6.0/24
ip prefix-list SPOKE-VNET seq 50 permit 10.0.0.0/8
!
route-map SPIN permit 20
exit
!
route-map RSIN permit 20
 match ip address prefix-list ONPREM
exit
!
route-map FW permit 10
 match ip address prefix-list DEFFW
 set ip next-hop 10.100.0.10
exit
!
route-map SPOUT permit 20
 match ip address prefix-list SPOKE-VNET
 set ip next-hop unchanged
exit
!
route-map SPOUT permit 30
 match ip address prefix-list DEFFW
 set ip next-hop 10.100.0.10
exit
!
route-map SPOUT permit 40
 match ip address prefix-list SPMAJOR
 set ip next-hop 10.17.33.254
exit
!
route-map RSOUT deny 5
 match ip address prefix-list DEFFW
exit
!
route-map RSOUT deny 6
 match ip address prefix-list SPMAJOR
exit
!
route-map RSOUT permit 10
 set ip next-hop unchanged
exit
!
end
SEA-Cust33-nva1#
```

## <a name="iptables"></a>3. Internet breakout 
The spoke vnets can breakout in internet through the **SEA-Cust33-fwvm** in **SEA-Cust33-fw** vnet.
iptables can be configured in **SEA-Cust33-fwvm** with simple NAT masquerade.

```bash
# enable ip forwarding
sed -i -e '$a\net.ipv4.ip_forward = 1' /etc/sysctl.conf
# to apply the change
sysctl -p
# check the change
sysctl net.ipv4.ip_forward

# define the iptables rules
iptables -I INPUT 1 -i lo -j ACCEPT;
iptables -A INPUT -p tcp --dport ssh -j ACCEPT;
iptables -A INPUT -p all -s 168.63.129.16 -j ACCEPT;
iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT;
iptables -A INPUT -p icmp --icmp-type echo-request -j ACCEPT;
iptables -A INPUT -j DROP;
iptables -P FORWARD ACCEPT;
iptables -P OUTPUT ACCEPT;
iptables -t nat -A PREROUTING -i eth0 -s 10.0.4.0/24,10.0.5.0/24,10.0.6.0/24 -j ACCEPT;
iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE;
```

To check the iptables rules:
```bash
iptables -nvL
iptables -t nat -nvL
```

Static routes are required in **SEA-Cust33-fwvm** to reach out the spoke vnets. <br>
Edit the file **/etc/netplan/50-cloud-init.yaml** and add the static routes as below:
```console
root@SEA-Cust33-fwvm1:~# cat /etc/netplan/50-cloud-init.yaml
# This file is generated from information provided by the datasource.  Changes
# to it will not persist across an instance reboot.  To disable cloud-init's
# network configuration capabilities, write a file
# /etc/cloud/cloud.cfg.d/99-disable-network-config.cfg with the following:
# network: {config: disabled}
network:
    ethernets:
        eth0:
            dhcp4: true
            dhcp4-overrides:
                route-metric: 100
            dhcp6: false
            match:
                driver: hv_netvsc
                macaddress: 00:22:48:78:4b:6d
            set-name: eth0
            routes:
            - to: 10.0.4.0/24
              via: 10.100.0.1
            - to: 10.0.5.0/24
              via: 10.100.0.1
            - to: 10.0.6.0/24
              via: 10.100.0.1
    version: 2
```
To apply the new network configuration:
```console
netplan try
```
The command **ip route** shows the new static routes:
```
root@SEA-Cust33-fwvm1:~# ip route
default via 10.100.0.1 dev eth0 proto dhcp src 10.100.0.10 metric 100
10.0.4.0/24 via 10.100.0.1 dev eth0 proto static onlink
10.0.5.0/24 via 10.100.0.1 dev eth0 proto static onlink
10.0.6.0/24 via 10.100.0.1 dev eth0 proto static onlink
10.100.0.0/25 dev eth0 proto kernel scope link src 10.100.0.10 metric 100
10.100.0.1 dev eth0 proto dhcp scope link src 10.100.0.10 metric 100
168.63.129.16 via 10.100.0.1 dev eth0 proto dhcp src 10.100.0.10 metric 100
169.254.169.254 via 10.100.0.1 dev eth0 proto dhcp src 10.100.0.10 metric 100
```

## <a name="Effective routing tables"></a>4. Routing table in crs1

BGP table in crs1:
```
SEA-Cust33-csr1#show ip bgp summary | begin Neighbor
Neighbor        V           AS MsgRcvd MsgSent   TblVer  InQ OutQ Up/Down  State/PfxRcd
10.0.4.4        4        65515     181     178        7    0    0 02:36:38        1
10.0.4.5        4        65515     181     179        7    0    0 02:36:37        1
10.0.5.4        4        65515     180     179        7    0    0 02:36:39        1
10.0.5.5        4        65515     181     177        7    0    0 02:36:38        1
10.0.6.4        4        65515     181     179        7    0    0 02:36:34        1
10.0.6.5        4        65515     180     177        7    0    0 02:36:36        1
10.17.33.68     4        65515     181     179        7    0    0 02:36:37        1
10.17.33.69     4        65515     184     181        7    0    0 02:36:39        1

SEA-Cust33-csr1#show ip bgp
BGP table version is 7, local router ID is 10.17.33.21
Status codes: s suppressed, d damped, h history, * valid, > best, i - internal,
              r RIB-failure, S Stale, m multipath, b backup-path, f RT-Filter,
              x best-external, a additional-path, c RIB-compressed,
              t secondary path, L long-lived-stale,
Origin codes: i - IGP, e - EGP, ? - incomplete
RPKI validation codes: V valid, I invalid, N Not found

     Network          Next Hop            Metric LocPrf Weight Path
 *>   0.0.0.0          10.17.33.17              0         32768 i
 *>   10.0.0.0         10.17.33.68                            0 65515 12076 65020 i
 *                     10.17.33.69                            0 65515 12076 65020 i
 *    10.0.4.0/24      10.0.4.5                               0 65515 i
 *>                    10.0.4.4                               0 65515 i
 *>   10.0.4.0/22      0.0.0.0                            32768 i
 *    10.0.5.0/24      10.0.5.5                               0 65515 i
 *>                    10.0.5.4                               0 65515 i
 *>   10.0.6.0/24      10.0.6.4                               0 65515 i
 *                     10.0.6.5                               0 65515 i
```
Check the presence of BGP filter incoming and outgoing with Route server in the hub vnet:
```
SEA-Cust33-csr1#show ip bgp neighbors 10.17.33.68 | sec Route map
  Route map for incoming advertisements is RSIN
  Route map for outgoing advertisements is RSOUT
```

The csr1 advertise to the Route Server in the hub the following networks:
```console
SEA-Cust33-csr1#show ip bgp neighbors 10.17.33.68 advertised-routes
BGP table version is 7, local router ID is 10.17.33.21
Status codes: s suppressed, d damped, h history, * valid, > best, i - internal,
              r RIB-failure, S Stale, m multipath, b backup-path, f RT-Filter,
              x best-external, a additional-path, c RIB-compressed,
              t secondary path, L long-lived-stale,
Origin codes: i - IGP, e - EGP, ? - incomplete
RPKI validation codes: V valid, I invalid, N Not found

     Network          Next Hop            Metric LocPrf Weight Path
 *>   10.0.0.0         10.17.33.68                            0 65515 12076 65020 i
 *>   10.0.4.0/24      10.0.4.4                               0 65515 i
 *>   10.0.5.0/24      10.0.5.4                               0 65515 i
 *>   10.0.6.0/24      10.0.6.4                               0 65515 i

Total number of prefixes 4
```

The csr1 learns from the Route Server in the hub the following networks:
```console
SEA-Cust33-csr1#show ip bgp neighbors 10.17.33.68 received-routes
BGP table version is 7, local router ID is 10.17.33.21
Status codes: s suppressed, d damped, h history, * valid, > best, i - internal,
              r RIB-failure, S Stale, m multipath, b backup-path, f RT-Filter,
              x best-external, a additional-path, c RIB-compressed,
              t secondary path, L long-lived-stale,
Origin codes: i - IGP, e - EGP, ? - incomplete
RPKI validation codes: V valid, I invalid, N Not found

     Network          Next Hop            Metric LocPrf Weight Path
 *>   10.0.0.0         10.17.33.68                            0 65515 12076 65020 i
 *    10.17.33.0/24    10.17.33.68                            0 65515 i
 *    192.168.33.0/31  10.17.33.68                            0 65515 12076 65020 i
 *    192.168.33.2/31  10.17.33.68                            0 65515 12076 65020 i
 Total number of prefixes 4
```

Check the presence of BGP filter incoming and outgoing with Route server in the spoke4 vnet:
```
SEA-Cust33-csr1#show ip bgp neighbors 10.0.4.4 | sec Route map
  Route map for incoming advertisements is SPIN
  Route map for outgoing advertisements is SPOUT
```

The csr1 advertise to the Route Server in the spoke4 the following networks:
```console
SEA-Cust33-csr1#show ip bgp neighbors 10.0.4.4 advertised-routes
BGP table version is 7, local router ID is 10.17.33.21
Status codes: s suppressed, d damped, h history, * valid, > best, i - internal,
              r RIB-failure, S Stale, m multipath, b backup-path, f RT-Filter,
              x best-external, a additional-path, c RIB-compressed,
              t secondary path, L long-lived-stale,
Origin codes: i - IGP, e - EGP, ? - incomplete
RPKI validation codes: V valid, I invalid, N Not found

     Network          Next Hop            Metric LocPrf Weight Path
 *>   0.0.0.0          10.17.33.17              0         32768 i
 *>   10.0.0.0         10.17.33.68                            0 65515 12076 65020 i
 *>   10.0.4.0/22      0.0.0.0                            32768 i
```
The csr1 learns from the Route Server in the spoke4 the following networks:
```
SEA-Cust33-csr1#show ip bgp neighbors 10.0.4.4 received-routes
BGP table version is 7, local router ID is 10.17.33.21
Status codes: s suppressed, d damped, h history, * valid, > best, i - internal,
              r RIB-failure, S Stale, m multipath, b backup-path, f RT-Filter,
              x best-external, a additional-path, c RIB-compressed,
              t secondary path, L long-lived-stale,
Origin codes: i - IGP, e - EGP, ? - incomplete
RPKI validation codes: V valid, I invalid, N Not found

     Network          Next Hop            Metric LocPrf Weight Path
 *>   10.0.4.0/24      10.0.4.4                               0 65515 i

Total number of prefixes 1
```

## <a name="Routing tables of the Route Servers in spoke vnets"></a>5. Routing tables of the Route Servers in spoke vnets

[![5]][5]

[![6]][6]

[![7]][7]

## <a name="Routing tables of the Route Server in hub vnet"></a>6. Routing tables of the Route Server in hub vnet

[![8]][8]

## <a name="Routing tables of the Expressroute Gateway"></a>7. Routing tables of the Expressroute Gateway

[![9]][9]

## <a name="Routing tables of the Expressroute circuit"></a>8. Routing tables of the Expressroute circuit

[![9]][9]

## <a name="Routing tables of the Expressroute circuit"></a>9. effective routing table of spoke4vm1


[![10]][10]

## Annex: IP packet capture in transit through a Cisco CSR
IOS XE command to capture the traffic through an interface:
```console
!  filter is applicable to limit the capture to desired traffic. 
! Define an Access Control List (ACL) within config mode and apply the filter to the buffer:
ip access-list extended BUF-FILTER
   10 permit ip 10.0.4.0 0.0.0.255 any
   20 permit ip 10.0.5.0 0.0.0.255 any
   30 permit ip 10.0.6.0 0.0.0.255 any

! Define a 'capture buffer', which is a temporary buffer where the captured packets are stored.
monitor capture CAP buffer size 5 access-list BUF-FILTER interface gigabitEthernet 2 both

! start the capture
monitor capture CAP start

! stop the capture
monitor capture CAP stop

! show the content of the capture buffer
show monitor capture CAP buffer brief

! show the content details of capture buffer
show monitor capture CAP buffer detailed 

! delete the capture buffer
monitor capture CAP clear

! disable the capture
no monitor capture CAP
```
The data path between spoke vnet and on-premises is shown below:

[![11]][11]

`Tags: Route Server, hub-spoke vnets, ExpressRoute Gateway ` <br>
`date: 16-02-23`

<!--Image References-->

[1]: ./media/network-diagram1.png "network diagram"
[2]: ./media/network-diagram2.png "full network diagram with BGP peering with csr1 in hub vnet"
[3]: ./media/network-diagram3.png "full network diagram with BGP peering with FRR in hub vnet"
[4]: ./media/network-diagram4.png "route filters in nva1"
[5]: ./media/rsspoke4.png "Route Server routing table in spoke4 vnet"
[6]: ./media/rsspoke5.png "Route Server routing table in spoke5 vnet"
[7]: ./media/rsspoke6.png "Route Server routing table in spoke6 vnet"
[8]: ./media/rsshub.png "Route Server routing table in hub vnet"
[9]: ./media/er-gw.png "Route Server routing table in hub vnet"
[10]: ./media/spoke4vm1.png "effective routing table of spoke4vm1 VM"
[11]: ./media/spoke-onprem.png "data path spoke - onpremises"
<!--Link References-->

