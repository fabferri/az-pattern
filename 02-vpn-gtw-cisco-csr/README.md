<properties
   pageTitle="site-to-site VPN between a Cisco CSR 1000v and Azure VPN Gateway"
   description="configuration of a VPN IPSec tunnel between  Cisco CSR 1000v and Azure VPN Gateway"
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
##  Site-to-site VPN between a Cisco CSR 1000v and Azure VPN Gateway

The article reports the scripts and Azure templates to create site-to-site VPN btween a Cisco CSR 1000v and Azure VPN. 
Here the network topology :

[![0]][0]

Two IPSec tunnels are established between the Cisco CSR and the VPN Gateway configured in active-active.

Steps to create the enviroment
- **step1**: run csr.ps1; the powershell deploys "csr.json"
- **step1b** *[optional step]*: run getpubIP-csr.ps1 to check the public IP of the csr 
- **step2**: run s2s-vpn.ps1; the powershell deploys "s2s-vpn.json"
- **step2b** *[optional step]*: run the powershell getpubIP-vpn.ps1 to get the public IPs of the VPN Gateway and the BGP peer addresses.
- **step3**: run generate-csr-config.ps1 to generate the configuration of the csr. 
       The script generates the configuration in a text file (csr-config.txt). if the file already exists, it is overwrite.
- **step4**: login on the console of the CSR and enter in config mode (csr command: conf t)
- **step5**: paste in the console of CSR the config generated from text file
- **step6**: on the csr console run the command check the IPSec tunnels are up:
       csr# show crypto session 
       csr# show crypto ipsec sa
       csr# show ip bgp
       csr# show ip route
       csr# show ip bgp neighbor 10.0.10.228 routes
       csr# show ip bgp neighbor 10.0.10.228 routes
- **step7**: run the powershell routingTableVPN.ps1 to get the route advertised from csr to the VPN gateway
LocalAddress Network        NextHop     SourcePeer  Origin  AsPath Weight
------------ -------        -------     ----------  ------  ------ ------
10.0.10.228  10.0.10.0/24               10.0.10.228 Network         32768
10.0.10.228  172.168.1.1/32             10.0.10.228 Network         32768
10.0.10.228  172.168.1.1/32 10.0.10.229 10.0.10.229 IBgp            32768
10.0.10.228  10.1.1.0/24    172.168.1.1 172.168.1.1 EBgp    65011   32768
10.0.10.228  10.1.1.0/24    10.0.10.229 10.0.10.229 IBgp    65011   32768
10.0.10.228  10.1.2.0/24    172.168.1.1 172.168.1.1 EBgp    65011   32768
10.0.10.228  10.1.2.0/24    10.0.10.229 10.0.10.229 IBgp    65011   32768
10.0.10.229  10.0.10.0/24               10.0.10.229 Network         32768
10.0.10.229  172.168.1.1/32             10.0.10.229 Network         32768
10.0.10.229  172.168.1.1/32 10.0.10.228 10.0.10.228 IBgp            32768
10.0.10.229  10.1.1.0/24    172.168.1.1 172.168.1.1 EBgp    65011   32768
10.0.10.229  10.1.1.0/24    10.0.10.228 10.0.10.228 IBgp    65011   32768
10.0.10.229  10.1.2.0/24    172.168.1.1 172.168.1.1 EBgp    65011   32768
10.0.10.229  10.1.2.0/24    10.0.10.228 10.0.10.228 IBgp    65011   32768


<!--Image References-->
[0]: ./media/network-diagram.png "Network Diagram" 


<!--Link References-->



