<properties
pageTitle= 'Network Watcher packet capture for virtual machine scale sets'
description= "Packet captures in Virtual Machine Scale Sets with Azure Network Watcher"
services="Azure Network Watcher"
documentationCenter="https://github.com/fabferri/"
authors="fabferri"
editor=""/>

<tags
   ms.service="configuration-Example-Azure"
   ms.devlang="ARM template"
   ms.topic="article"
   ms.tgt_pltfrm="Azure"
   ms.workload="Azure Network Watcher"
   ms.date="31/08/2022"
   ms.author="fabferri" />

# Packet captures in Virtual Machine Scale Sets with Azure Network Watcher
Network Watcher packet capture allows you to create packet capture sessions to collect traffic to and from virtual machine scale set (VMSS) instances. This will help to diagnose network anomalies both reactively and proactively. <br>
The network diagram is shown below:

[![1]][1]

- The vnet has a single subnet where are deployed an ubuntu VM with public IP, an internal load balancer with VMSS in the backend pool.
- The VM with public IP is used as jumpbox to access to the VMSS instances.
- The internal load balancer is configured with inbound NAT rule with Frontend port start range set to 50000 that allow to access to VMSS instances in SSH through different ports
- the internal load balancer use 
- From the jumpbox VM, you can login in SSH to the first instance of VMSS using the port 50000, to second instances to the port 50001 and so on.
- A network security group is applied to the subnet. Packet capture requires the following <ins>outbound</ins> TCP connectivity: 
   - TCP port 443 to reach out the storage account
   - to 169.254.169.254 over port 80
   - to 168.63.129.16 over port 8037

[![2]][2]

In the VMSS are installed two extensions: **NetworkWatcherAgentLinux** and **CustomScript** <br>
Packet capture run through an extension **NetworkWatcherAgentLinux** installed in VMSS that is remotely started through Network Watcher. <br>  
The linux custom script extension is used for: 
- installation of nginx in VMSS and set the HTTP listen port to 8080 
- installation of iperf3. This is an arbitrary choice used to generate traffic between the VMSS instances. You can replace it with your own application.
<br>

Network Watcher packet capture simply the process of running the capture on desired VMSS instances; you do not need to login in the VMSS instance and start the process of capture manually, but the process of capture is managed through Network Watcher. Capability to be able to remotely trigger packet captures remotely, saves valuable time. <br>
Packet capture in VMSS can be triggered through the Azure Management portal, PowerShell, CLI, or ARM template or REST API. In our project an ARM template is used to define and start the packet capture.
Network Watcher packet capture allows you to create capture sessions to track traffic to and from a virtual machine scale set instance/(s). <br>
Filters are provided for the capture session to ensure you capture only the traffic you want to monitor. Filters are based on 5-tuple (protocol, local IP address, remote IP address, local port, and remote port) information. The captured data is stored in the local disk or a storage blob. 



## <a name="List of files"></a>1. List of files 
| file                    | Description                                                            | 
| ----------------------- |----------------------------------------------------------------------- | 
| **init.json**           | input parameter file defining: Azure subscription, Resource group name |
| **vmss.json**           | ARM template to deploy jumpbox VM internal load balancer, VMSS         |
| **vmss-parameters.json**| ARM template parameter file to feed the values of **vmss.json**        |
| **vmss.ps1**            | powershell to run **vmss.json**; it reads the variables specified in **init.json**|
| **capture.json**        | ARM template to define and start the packet capture                    |
| **capture.ps1**         | powershell script to deploy the ARM template **capture.json**          |

**NOTE:**
- The sequence of steps to run the deployment:
   1. customize the values of input variables in **init.json** and **vmss-parameters.json**
   2. change the administrator username and administrator password of the VM and VMSS in the **vmss-parameters.json**
   3. run the powershell **vmss.ps1**: the ARM template **vmss.json** is deployed
   4. run the powershell **capture.ps1** to start the packet captures. **capture.ps1** deploys the ARM template **vmss.json**.
   5. connect to the VMSS instance_0 and start the iperf3 receiver by the command: **iperf3 -s**
   6. connect to the VMSS instance_1 and start the iperf3 sender by the command: **iperf3 -c 10.0.0.4**
   7. from a client in internet, you can connect to the storage account to download the packet captures (files: *.cap) locally in the client
   8. in the client, by wireshark open a packet capture and set a display filter, like **tcp.port == 5201**, to see only the iperf3 traffic between VMSS instance_1 and instance_0 


## <a name="ARM template to trigger the packet captures"></a>2. ARM template to trigger the packet captures

```json
        {
            "type": "Microsoft.Resources/deployments",
            "apiVersion": "2021-04-01",
            "name": "deployPacketCapture",
            "resourceGroup": "[variables('NetworkWatcherResourceGroup')]",
            "dependsOn": [],
            "properties": {
                "mode": "Incremental",
                "template": {
                    "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#",
                    "contentVersion": "1.0.0.0",
                    "parameters": {},
                    "resources": [
                        {
                            "type": "Microsoft.Network/networkWatchers/packetCaptures",
                            "name": "[concat(variables('NetworkWatcherName'), '/',variables('packetCaptureName'))]",
                            "apiVersion": "2022-01-01",
                            "properties": {
                                "target": "[resourceId( variables('subscriptionIdvmScaleSet'), variables('resourceGroupvmScaleSet'),'Microsoft.Compute/virtualMachineScaleSets',variables('vmScaleSetName'))]",
                                "scope": {
                                    "include": [
                                        "0",
                                        "1",
                                        "2"
                                    ],
                                    "exclude": []
                                },
                                "targetType": "AzureVMSS",
                                "bytesToCapturePerPacket": 0,
                                "totalBytesPerSession": 1073741824,
                                "timeLimitInSeconds": 18000,
                                "storageLocation": {
                                    "storageId": "[resourceId(variables('subscriptionIdvmScaleSet'),variables('resourceGroupvmScaleSet'), 'Microsoft.Storage/storageAccounts', variables('storageAccountName'))]",
                                    "storagePath": "[concat( reference(resourceId('Microsoft.Storage/storageAccounts', variables('storageAccountName')),'2021-06-01').primaryEndpoints.blob, 'network-watcher-logs','/', variables('packetCaptureName'), '.cap')]"
                                },
                                "filters": [
                                    {
                                        "protocol": "TCP",
                                        "localIPAddress": "10.0.0.4-10.0.0.20",
                                        "localPort": "5201",
                                        "remoteIPAddress": "10.0.0.4-10.0.0.20",
                                        "remotePort": "1-65532"
                                    }
                                ]
                            }
                        }
                    ]
                }
            }
        }

```

- Network Watcher is deployed in different resource group from the resource group of VMSS; the benefit to use **Microsoft.Resources/deployments** is in the possibility to deploy child objects of Network Watcher, specificy the parent resource group (Network Watcher resource group).
- in the section **scope** is possibile define the packet captures in specific VMSS instances. In the template above the packet capture runs in three VMSS instances: instance0, instance1, instance2
- the capture uses a filter based on network source, network destination, source port, destination port. The template above allows an iperf3 traffic capture between VMSS instances 

<!--Image References-->

[1]: ./media/network-diagram1.png "network diagram"
[2]: ./media/network-diagram2.png "how to login in different VMSS instances from the jumpbox VM"

<!--Link References-->

