<properties
pageTitle= 'Virtual WAN with virtual hub in BGP peering with Juniper Session Smart Router'
description= "Virtual WAN with virtual hub in BGP peering with Juniper Session Smart Router"
documentationcenter: na
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
   ms.date="23/01/2021"
   ms.author="fabferri" />

## Virtual WAN with virtual hub in BGP peering with Juniper Session Smart Router

The article walks through the interoperability between the Virtual WAN and Juniper Session Smart Router (formerly 128T). The communication is implemented through BGP peering between one Juniper Session Smart (SSR) and the virtual hub.
<br>

The network diagram is shown below:

[![1]][1]

* full deployment is done through ARM templates.
* the ARM templates to deploy the conductor and SSR use the BYOL image in the azure marketplace, that doesn't support the automatic configuration. After the bootstrap of conductor and session smart routers (r1, r2, r3), the installation is executed manually
* The ssr-r1 establishes a BGP peering with Route Server in the virtual hub.
* the Virtual WAN (vWAN) has a single virtual hub with only a connection with a spoke vnet
* The target configuration is to establish an any-to-any communication between all the VMs, attached to the VNets with smart routers and in spoke vnet connected to virtual hub.

### Caveats
### This article can be used in testbed environment and it is not extensive tested.
### The scripts and ARM templates are not ready to be used in production.
### Deployment of SSR routers and conductor use BYOL; installation can be completed only by Juniper license. To get the right license, please contact a Juniper representative to ask for. Without license you won't be able to make the setup.
<br>

### <a name="List"></a>1. List of files

| File name           | Description                                                |
| ------------------- | ---------------------------------------------------------- |
| **init.json**       |  list of variables used as input for all ARM templates     |
| **00-keyvault.json**|  ARM template to deploy keyvault and store the  administrator credential |
| **00-keyvault.ps1** |  powershell script to run **00-keyvault.json**             |
| **conductor.json**  |  ARM template to deploy the SSR conductor (_controller_)   |
| **conductor.ps1**   |  powershell script to run **conductor.json**               |
| **router1.json**    |  ARM template to deploy the session smart router **r1**    |
| **router1.ps1**     |  powershell script to run **router1.json**                 |
| **router2.json**    |  ARM template to deploy the session smart router **r2**    |
| **router2.ps1**     |  powershell script to run **router2.json**                 |
| **router3.json**    |  ARM template to deploy the session smart router **r3**    |
| **router3.ps1**     |  powershell script to run **router3.json**                 |
| **route-tables.json** |  ARM template to create the UDRs and apply them to the subnets. <br> In case the VNets should not exist, the template create all of them.  |
| **route-tables.ps1**|  powershell script to run **route-tables.json**            |
| **create-vms.json** |  ARM template to create all the VMs in the VNets (vnet1, vnet2, vnet3, spoke1) |
| **create-vms.ps1**  |  powershell script to run **create-vms.json**              |
| **vwan.json**       |  ARM template to deploy virtual WAN with virtual hub1 and create a connection with vnet1.      |
| **vwan.ps1**        |  powershell script to run **vwan.json**                              |
| **bgp-peering.json**|  ARM template to configure in vWAN the BGP peering in Virtual Router |
| **bgp-peering.ps1** |  powershell script to run **bgp-peering.json**             |
| **ssr-generate-full-config** | powershell script collects all the parameters required to generate the full configuration of all SSRs. The script generates in output a text file named **ssr-config.txt**. The content of this file needs to be cut-and-pasted in the CLI of the conductor. |
| **grab-IPs**        | powershell script grabs private and public IP addresses of all ethernet interface of router r1, r2,r3|

### <a name="Dependency"></a>2. Dependency
Let's discuss in summary some dependencies in execution of the ARM templates.

- **00-keyvault.json** should be the first object to deploy, to store the administrator credential in the secret.
- **conductor.json** and **router1.json**,**router2.json**, **router3.json** can run in parallel.  Manual setup of SSRs (r1, r2, r3) can be done only after the deployment of conductor, needs of because the manual steps of configuration of SSR require to reference the public IP of the conductor.
- **vwan.json** establish a vnet connection with **vnet1**. Run **vwan.json** after the execution of **route-tables.json**  or **router1.json**  
- **bgp-peering.json** can run successful only after the deployment of **vwan.json**

A possible execution workflow:

[![2]][2]

### <a name="Dependency"></a>3. Configuration of SSR
After bootstrapping of the router r1, r2, r3 connect in SSH to each VM. A screen pop-up with installation wizard of SSR software:

[![3]][3]
<br>

Skip the Username and Token and paste the full content of .PEM file Juniper provided you:

[![4]][4]


<br>
Select the image you want to install:

[![5]][5]

Select the option **Conductor** or **Router**, based on what you want to install:

[![6]][6]

Specify standalone or HA installation type:
[![7]][7]

Installation of session smart router requires the public IP of the conductor:
[![10]][10]

## <a name="SSRconfiguration"></a>3. Generate the full configuration of Session Smart Routers (SSRs)
Connect in SSH to each SSR to pickup the VM BUS ID for each ethernet interfaces; two commands can be used for the purpose as reported below: 

```console
[root@r1 ~]# sudo basename $(readlink /sys/class/net/eth0/device)
000d3a6c-e3c6-000d-3a6c-e3c6000d3a6c
[root@r1 ~]# sudo basename $(readlink /sys/class/net/eth1/device)
000d3a6c-ed37-000d-3a6c-ed37000d3a6c
[root@r1 ~]# sudo basename $(readlink /sys/class/net/eth2/device)
000d3a6c-e668-000d-3a6c-e668000d3a6c
-----------------------------------------------------------------
[root@r1 ~]# sudo dpdk-devbind.py --status

Network devices using kernel driver
===================================
22d7:00:02.0 'MT27500/MT27520 Family [ConnectX-3/ConnectX-3 Pro Virtual Function                                                          ] 1004' if=eth4 drv=mlx4_core unused=igb_uio,vfio-pci
5826:00:02.0 'MT27500/MT27520 Family [ConnectX-3/ConnectX-3 Pro Virtual Function                                                          ] 1004' if=eth5 drv=mlx4_core unused=igb_uio,vfio-pci
d2e3:00:02.0 'MT27500/MT27520 Family [ConnectX-3/ConnectX-3 Pro Virtual Function                                                          ] 1004' if=eth3 drv=mlx4_core unused=igb_uio,vfio-pci

VMBus devices
=============
000d3a6c-e3c6-000d-3a6c-e3c6000d3a6c 'Synthetic network adapter' if=eth0 drv=hv_                                                          netvsc
000d3a6c-e668-000d-3a6c-e668000d3a6c 'Synthetic network adapter' if=eth2 drv=hv_                                                          netvsc
000d3a6c-ed37-000d-3a6c-ed37000d3a6c 'Synthetic network adapter' if=eth1 drv=hv_ 
```

Write the values of VMBUS IDs of ethernet interfaces of r1, r2, r3 in the script **ssr-generate-full-config.ps1**:
```console
$r1_nicMng_vmbusId  = '000d3a6c-e3c6-000d-3a6c-e3c6000d3a6c'
$r1_nicPub_vmbusId  = '000d3a6c-ed37-000d-3a6c-ed37000d3a6c'
$r1_nicPriv_vmbusId = '000d3a6c-e668-000d-3a6c-e668000d3a6c'

$r2_nicMng_vmbusId =  '000d3a6c-e374-000d-3a6c-e374000d3a6c'
$r2_nicPub_vmbusId =  '000d3a6c-e21f-000d-3a6c-e21f000d3a6c'
$r2_nicPriv_vmbusId = '000d3a6c-e516-000d-3a6c-e516000d3a6c'

$r3_nicMng_vmbusId  = '000d3af5-9754-000d-3af5-9754000d3af5'
$r3_nicPub_vmbusId  = '000d3af5-9061-000d-3af5-9061000d3af5'
$r3_nicPriv_vmbusId = '000d3af5-9d7c-000d-3af5-9d7c000d3af5'
```

At this point, the powershell script **ssr-generate-full-config.ps1** has all the information to generate the full configuration of all SSRs. The powershell script **ssr-generate-full-config.ps1** generates in output a text file named **ssr-config.txt**.

### <a name="SSRconfiguration"></a>4. Manual configuration of the SSRs
Connect in SSH as admin to the conductor; the PCLI starts automatically:
```console
[128conductor ~]#
Starting the PCLI...
admin@conductor.conductor#

admin@128conductor.conductor# show config running
config

    authority

        remote-login

        exit

        router        conductor
            name  conductor

            node  conductor
                name  conductor
            exit
        exit
    exit
exit

admin@128conductor.conductor# show config running flat

config authority router conductor name  conductor

config authority router conductor node conductor name  conductor
```

It is possible to copy-and-paste snippets or full directly into conductor. The PCLI detects configuration entered in bulk and accepts input in either show config native format or flat format.
<br>

### PASTE the content of the file ssr-config.txt into the PCLI
### by PCLI command: commit, commits the candidate config as the new running config.
<br>

The 'commit' command causes the 128T router to validate the candidate configuration, and then replace the running
configuration with the candidate configuration (assuming it passes the validation step). 
<br>
When run from a 128T conductor, the conductor will first validate the configuration itself before distributing
configuration to all of its managed routers for each of them to validate the configuration. After the managed routers
have all reported the results of their validation, the commit activity takes place (assuming a successful validation).

If the validation step fails, the administrator will be notified, the commit step is not executed, and the existing
running configuration will remain in place. The validator will get a list of all errors that must be addressed before
the commit can be completed. 

```console
admin@conductor.conductor# commit
Are you sure you want to commit the candidate config? [y/N]: y
✔ Validating, then committing...
Configuration committed
*admin@conductor.conductor#
```

## Short list of PCLI commands 
| Description                                         | command                      |
| --------------------------------------------------- | ---------------------------- |
| visualize running configuration                     | show config running          |
| visualize running configuration as a series of individual statements|show config running flat| 
| Display configuration exports                       | show config exports          |
| To commit a candidate configuration                 | commit                       |
| To commit a candidate configuration and distribute config to each managed router for validation and wait for results before committing                                            | commit validate-router-all   |
| Compare configurations                              | compare config `<OLD> <NEW>` |
| To see the changes between the candidate and running configuration  | compare config                   |
| show the changes that have been made to the candidate configuration | compare config running candidate |
| To reset the candidate back to the system's runtime configuration| restore config running|
| To restore a 128T system back to its factory defaults| restore config factory-default |
| Either the candidate or running configuration can be backed up | export config running `<EXPORT-NAME>` |
| To import a configuration that has once been exported | import config `<FILE-NAME>` |

The IP addresses of the BGP peer in hub1 can be discovered by command:
```powershell
Get-AzVirtualHub -ResourceGroupName $rgName -Name hub1
```

### <a name="checking routing"></a>5. Checking routing
After applying the configuration to SSRs, a check on routing can be done by effective routes in the NIC of VM in spoke vnet:
```powershell
Get-AzEffectiveRouteTable -NetworkInterfaceName vm-spoke1-nic -ResourceGroupName $rgName | ft


Name DisableBgpRoutePropagation State  Source                AddressPrefix    NextHopType           NextHopIpAddress
---- -------------------------- -----  ------                -------------    -----------           ----------------
                          False Active Default               {10.101.1.0/24}  VnetLocal             {}
                          False Active Default               {10.10.0.0/23}   VNetPeering           {}
                          False Active VirtualNetworkGateway {10.0.1.0/24}    VirtualNetworkGateway {20.83.94.168}
                          False Active VirtualNetworkGateway {10.0.1.96/27}   VirtualNetworkGateway {20.83.94.168}
                          False Active VirtualNetworkGateway {10.0.3.96/27}   VirtualNetworkGateway {20.83.94.168}
                          False Active VirtualNetworkGateway {10.0.2.96/27}   VirtualNetworkGateway {20.83.94.168}
                          False Active Default               {0.0.0.0/0}      Internet              {}
```

### <a name="generate traffic"></a>6. Generate data traffic in transit
To generate traffic in transit you might install nginx in vm1, vm2, vm3, spoke1-vm and use a cycle with curl to send traffic:
```bash
root@vm-spoke1:~# for i in `seq 1 200`; do curl 10.0.2.100; done
```
The sessions can be tracked in the conductor:

[![11]][11]

<!--Image References-->

[1]: ./media/network-diagram.png "network diagram"
[2]: ./media/workflow.png "execution flow"
[3]: ./media/01.png "SSR screenshot"
[4]: ./media/02.png "SSR screenshot"
[5]: ./media/03.png "SSR screenshot"
[6]: ./media/04.png "SSR screenshot"
[7]: ./media/05.png "SSR screenshot"
[8]: ./media/06.png "SSR screenshot"
[9]: ./media/07.png "SSR screenshot"
[10]: ./media/08.png "SSR screenshot"
[11]: ./media/ssr-sessions.png "SSR screenshot"

<!--Link References-->

