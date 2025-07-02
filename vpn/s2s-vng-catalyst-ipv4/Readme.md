<properties
pageTitle= 'Site-to-Site IPsec tunnels between Azure VPN Gateway and Cisco Catalyst 8000v'
description= "Site-to-Site IPsec tunnels between Azure VPN Gateway and Cisco Catalyst 8000v"
services="Azure VPN Gateway"
documentationCenter="https://github.com/fabferri"
authors="fabferri"
editor="fabferri"/>

<tags
   ms.service="howto-Azure-examples"
   ms.devlang="na"
   ms.topic="article"
   ms.tgt_pltfrm="Azure"
   ms.workload="Azure VPN Gateway"
   ms.date="02/07/2025"
   ms.review=""
   ms.author="fabferri" />

# Site-to-Site IPsec tunnels between Azure VPN Gateway and Cisco Catalyst 8000v
The article walks you through a configuration with Site-to-Site IPsec tunnels between an Azure VPN Gateway in active-active mode and a Cisco Catalyst 8000v <br>
The network diagram is shown below:

[![1]][1]

The Catalyst NIC **cat-nic-untrust** has two IP configurations, each with public IP:

| Name          | IP version | Type     | Private IP address | Public IP address |       
| ------------- |:---------- |:-------- |:------------------ |:----------------- |
| ipconfig-v4   | IPv4       | Primary  | 10.2.0.90 (Static) |  cat2-pubIP3      |
| ipconfig-v4-2 | IPv4       | Secondary| 10.2.0.91 (Static) |  cat2-pubIP4      |

The diagram shows the IPsec tunnel through the **cat-nic-untrust** and the configuration of VPN Gateway with the two Local Network Gateway **localNetGaw1** and **localNetGw2**:

[![2]][2]

The Catalyst terminates the IPsec connections in the tunnel interfaces: **tunnel0** and **tunnel1**.

### <a name="file list"></a>1. File list

| file                 | description                                                                  |       
| -------------------- |:---------------------------------------------------------------------------- |
| **init.json**        | file with list of input variables                                            |
| **01-catalyst.json** | ARM template to create vnet2 with catalyst, UDRs and Azure VM connected to the app-subnet  |
| **01-catalyst.ps1**  | powershell script to deploy the ARM template **01-gws.json**                 |
| **02-azvng.json**    | ARM template to create the vnet1 and Azure VPN Gateway in active-active mode with custom encryption policy and connections |
| **02-azvng.ps1**     | powershell script to deploy the ARM template **02-azvng.json**               |
| **catalyst-gen-config.ps1**  | powershell script to generate the Catalyst 8000v configuration       |


Sequence of steps to make the deployment:
1. Customize the value of variables in **init.json**. This is the first step before running the deployment. if you do not specify the correct values, your deployment will fail.
1. Run the script **01-catalyst.ps1**
1. Run the command to accept the legal to spin up Cisco Catalyst image from azure marketplace (see below for more details). This needs to be done only the first time and it is not required in the future deployments.
1. Run the script **02-azvng.ps1**
1. Run the script **catalyst-gen-config.ps1**; a test file **catalyst-config01.txt** is created in local folder with Catalyst configuration.
1. Connect to the Catalyst 8000v and enable the license for IPsec: `license boot level network-advantage addon dna-advantage` (see more details below) than reboot the Catalyst.
1. After the reboot of the Catalyst, connect to the console of Catalyst and in configuration mode paste the content of the file **catalyst-config01.txt**

if you run **02-azvng.ps1** before **01-catalyst.ps1**, the configuration will fail becasue the Local Network Gateway in Azure VPN Gateway requires the Catalyst 8000v public IPs of untrusted interface.
<br>

## <a name="accept the terms and condition to spin up a Cisco Catalyst"></a>2. How to accept the terms and condition to spin up a Cisco Catalyst
To deploy a Catalyst is required the acceptance of license and condition in Azure marketplace. <br>
AZ CLI offers some useful command to make the work: https://learn.microsoft.com/en-us/cli/azure/vm/image/terms?view=azure-cli-latest

`az vm image terms accept --offer {offer} --plan {plan} --publisher {publisher}` <br>

set the subscription: `az account set --subscription "Hybrid-PM-Demo-1"` <br>
show the current subscription: `az account show` <br>
get the full list of images: `az vm image list --all --publisher cisco --offer cisco-c8000v-byol` <br>
get the list of skus: `az vm image list --all --publisher cisco --offer cisco-c8000v-byol --query '[].{sku:sku}'` <br>
get sku and urn: `az vm image list --all --publisher cisco --offer cisco-c8000v-byol --query '[].{sku:sku,urn:urn}'` <br>
`az vm image list --all --publisher cisco --offer cisco-c8000v-byol --sku 17_15_01a-byol --query '[0].urn'` <br>

Accept Azure Marketplace image terms so that the image can be used to create VMs: <br>
`az vm image terms accept --urn cisco:cisco-c8000v-byol:17_15_01a-byol:17.15.0120240903` <br>

Verification that legal has been fulfilled: <br>
`az vm image terms show --urn cisco:cisco-c8000v-byol:17_15_01a-byol:17.15.0120240903` <br>


## <a name="Enable license in the Catalyst"></a>3. Enable license in Cisco Catalyst 8000v 
As first action after the bootstrap of Catalyst is the setting of license to configure IPsec; in configuration mode:

```console
catalyst(config)# license boot level network-advantage addon dna-advantage
catalyst# write
catalyst# reload
```

## <a name="list of files"></a>4. Catalyst configuration with IPsec tunnels
Cisco Catalyst configuration with IPsec tunnels is shown below. The configuration is automatically generated by **catalyst-gen-config.ps1** script. The script **catalyst-gen-config.ps1** automatically replace the variables with the effective values.

Meaning of variables in Catalyst configuration:
- `$pubIP_RemoteGtw0`: VPN GTW-public IP address-instance_0 of the VPN Gateway
- `$pubIP_RemoteGtw1`: VPN GTW-public ip address-instance_1 of the VPN Gateway
- `$remoteVnetAddressSpace` = '10.1.0.0 255.255.255.0' <ins>(address prefix and mask of remote network)</ins>
- `$ip_Tunnel0`: Catalyst-IP ADDRESS of the tunnel0 interface
- `$ip_Tunnel1`: Catalyst-IP ADDRESS of the tunnel1 interface
- `$priv_externalNetw1`: Catalyst-private IP assigned to the UNTRUSTED primary NIC
- `$priv_externalNetw2`: Catalyst-private IP assigned to the UNTRUSTED secondary NIC
- `$mask_externalNetw` : "255.255.255.224"  <ins>(subnet mask of the IP assigned to the UNTRUSTED NIC) </ins>
- `$defaultGwUntrustedSubnet`: "10.2.0.65" <ins>(IP default gateway of the subnet attached to the UNTRUSTED NIC) </ins>

```Console
interface GigabitEthernet2
 ip address dhcp
 no shut
!
interface GigabitEthernet3
 ip address $priv_externalNetw1 $mask_externalNetw
 ip address $priv_externalNetw2 $mask_externalNetw secondary
 negotiation auto
 no shut
!
crypto ikev2 proposal az-PROPOSAL
 encryption aes-gcm-256 aes-gcm-128
 prf sha384 sha256
 group 14
!
crypto ikev2 policy az-POLICY
 proposal az-PROPOSAL
!
crypto ikev2 keyring az-KEYRING1
 peer az-gw-instance0
  address $pubIP_RemoteGtw0
  pre-shared-key $psk1
!
!
crypto ikev2 keyring az-KEYRING2
 peer az-gw-instance1
  address $pubIP_RemoteGtw1
  pre-shared-key $psk2
 !
crypto ikev2 profile az-PROFILE1
 match address local $priv_externalNetw1
 match identity remote address $pubIP_RemoteGtw0 255.255.255.255
 authentication remote pre-share
 authentication local pre-share
 keyring local az-KEYRING1
 dpd 40 2 on-demand
!
crypto ikev2 profile az-PROFILE2
 match address local $priv_externalNetw2
 match identity remote address $pubIP_RemoteGtw1 255.255.255.255
 authentication remote pre-share
 authentication local pre-share
 keyring local az-KEYRING2
 dpd 40 2 on-demand
!
crypto ipsec transform-set az-TRANSFORMSET esp-gcm 256
 mode tunnel
!
crypto ipsec profile az-IPSEC-PROFILE1
 set transform-set az-TRANSFORMSET
 set ikev2-profile az-PROFILE1
!
crypto ipsec profile az-IPSEC-PROFILE2
 set transform-set az-TRANSFORMSET
 set ikev2-profile az-PROFILE2
!
interface Tunnel0
 ip address $ip_Tunnel0 255.255.255.255
 ip tcp adjust-mss 1350
 tunnel source $priv_externalNetw1
 tunnel mode ipsec ipv4
 tunnel destination $pubIP_RemoteGtw0
 tunnel protection ipsec profile az-IPSEC-PROFILE1
!
interface Tunnel1
 ip address $ip_Tunnel1 255.255.255.255
 ip tcp adjust-mss 1350
 tunnel source $priv_externalNetw2
 tunnel mode ipsec ipv4
 tunnel destination $pubIP_RemoteGtw1
 tunnel protection ipsec profile az-IPSEC-PROFILE2
!
!
crypto ikev2 dpd 10 2 on-demand
!
! route set by ARM template
ip route 10.2.0.96 255.255.255.224 10.2.0.33
ip route  $pubIP_RemoteGtw0 255.255.255.255 $defaultGwUntrustedSubnet
ip route  $pubIP_RemoteGtw1 255.255.255.255 $defaultGwUntrustedSubnet
!
!
ip route $remoteVnetAddressSpace Tunnel0
ip route $remoteVnetAddressSpace Tunnel1

line vty 0 4
 exec-timeout 10 0
exit
```

## <a name="custom IKE phase1 and IKE phase2 in the Connection"></a>5. custom IPsec/IKE policies in the VPN Connection
The ARM template **01-catalyst.json** sets a custom IPsec and IKE policy in the connections:

```json
"ipsecPolicies": [
   {
      "saLifeTimeSeconds": 27000,
      "saDataSizeKilobytes": 0,
      "ipsecEncryption": "GCMAES256",
      "ipsecIntegrity": "GCMAES256",
      "ikeEncryption": "GCMAES256",
      "ikeIntegrity": "SHA384",
      "dhGroup": "DHGroup2048",
      "pfsGroup": "None"
   }
]
```
Configuration of connection in Azure Management portal:

[![3]][3]


## <a name="effective route tables"></a>6. Effective route tables in Azure VMs

Effective route table in **vm1-nic**:
```powershell
 Get-AzEffectiveRouteTable -NetworkInterfaceName vm1-nic -ResourceGroupName $rgName  | Select-Object -Property Source,State,AddressPrefix,NextHopType,NextHopIpAddress | ft

Source                State  AddressPrefix    NextHopType           NextHopIpAddress
------                -----  -------------    -----------           ----------------
Default               Active {10.1.0.0/24}    VnetLocal             {}
VirtualNetworkGateway Active {10.2.0.0/24}    VirtualNetworkGateway {10.1.0.228, 10.1.0.229}
Default               Active {0.0.0.0/0}      Internet              {}
```

Effective route table in **vm-cat-nic**:
```powershell
Get-AzEffectiveRouteTable -NetworkInterfaceName vm-cat-nic -ResourceGroupName $rgName  | Select-Object -Property Source,State,AddressPrefix,NextHopType,NextHopIpAddress | ft

------  -----  -------------    -----------      ----------------
Source  State  AddressPrefix    NextHopType      NextHopIpAddress
------  -----  -------------    -----------      ----------------
Default Active {10.2.0.0/24}    VnetLocal        {}
Default Active {0.0.0.0/0}      Internet         {}
User    Active {10.1.0.0/24}    VirtualAppliance {10.2.0.50}
```


## <a name="Annex"></a>7. Annex

### <a name="Catalyst commands to verify the IPsec tunnels"></a>7.1 Check IKEv2 and IPsec in Catalyst
In order to verify that the IPsec tunnel is up between the Catalyst and the Azure VPN gateway:

```console
cat2# show crypto session
cat2# show crypto ikev2 sa
cat2# show crypto ikev2 session
cat2# show crypto ipsec sa
```

### <a name="Catalyst commands"></a>7.2 Catalyst capture traffic commands

```console
! define the ACL to filter the traffic
ip access-list extended CAP-FILTER
  permit ip host 10.1.0.4 any
  permit ip any host 10.1.0.4
!  
! associate the named access lsit with the capture
monitor capture CAP access-list CAP-FILTER
! define the number of packets in the capture 
monitor capture CAP limit packets 2000
!
! define the network interface to apply the capture; 
! "both" enable inbound and outbound traffic capture on that interface
monitor capture CAP interface GigabitEthernet 2 both
!
! define the size of circular buffer
monitor capture CAP buffer circular size 10
!
! start the capture
monitor capture CAP start
!
!
! to show captures in progress: 
show monitor capture
!
! stop the capture
monitor capture CAP stop
!
! show the content of buffer
show monitor capture CAP buffer brief
! show the details of the capture
show monitor capture CAP buffer detailed
!
! export the capture to an ftp server.
! (note: Wireshark can open exported .pcap files)
monitor capture CAP export tftp://10.17.7.7/CAP.pcap
!
! delete the content in the capture buffer
monitor capture CAP clear 
!
! remove the capture
no monitor capture CAP
!
```

### <a name="Catalyst commands"></a>7.3 Catalyst debug commands

```console
! enable the output of debug/messages in the SSH session
terminal monitor
!
! debug IKEv2
debug crypto ikev2 protocol
debug crypto ikev2 platform
debug crypto ikev2 internal
debug crypto ikev2 packet
!
! disable the debug
undebug all
!
! disable the output of debug/messages in the SSH session
terminal no monitor
!
```

`Tags: Azure VPN, Site-to-Site VPN, Site-to-Site IPsec tunnels, Cisco Catalyst` <br>
`date: 02-07-2025` <br>

<!--Image References-->

[1]: ./media/network-diagram.png "network diagram"
[2]: ./media/tunnels.png "Site-to-Site IPsec tunnels"
[3]: ./media/connection1-config.png "Connection1 with custom IPSec/IKE policies"

<!--Link References-->
