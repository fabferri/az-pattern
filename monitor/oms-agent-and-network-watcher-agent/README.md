<properties
pageTitle= 'Monitor with OMS agent and network watcher agent'
description= "Azure Connection Monitor"
documentationcenter: na
services="Azure Monitor"
documentationCenter="na"
authors="fabferri"
manager=""
editor=""/>

<tags
   ms.service="configuration-Example-Azure"
   ms.devlang="na"
   ms.topic="article"
   ms.tgt_pltfrm="Azure"
   ms.workload="na"
   ms.date="30/04/2022"
   ms.author="fabferri" />

# Monitor with OMS agent and network watcher agent
The **Log Analytics agents** (OMs agent) are on a deprecation path and will no longer be supported after August 31, 2024. If you use the Log Analytics agents to ingest data to Azure Monitor, make sure to migrate to the new **Azure Monitor agent** prior to that date. This article discusses a configuration with OMs agent for data ingestion to log analytics workspace.
<br>
The network diagram of our environment is shown below:

[![1]][1]



## <a name="List of files"></a>1. List of files 

| file                     | description                                                               |       
| ------------------------ |:------------------------------------------------------------------------- |
| **01-log-analytics.json**| ARM template to create the Log Analytics workspace                        |
| **01-log-analytics.ps1** | powershell script to deploy the ARM template **01-log-analytics.json**    |
| **02-vnet1-vms.json**    | ARM template to create vnet1, Expressroute Gateway, connection and Windows VMs in the vnet1 |
| **02-vnet1-vms.ps1**     | powershell script to deploy the ARM template **02-vnet1-vms.json**        |
| **03-vnet2-vms.json**    | ARM template to create vnet2 and VMs in the vnet2                         |
| **03-vnet2-vms.ps1**     | powershell script to deploy the ARM template **03-vnet2-vms.json**        |
| **04-vnet-peering.json** | ARM template to create the vnet peering between vnet1 and vnet2           |
| **04-vnet-peering.ps1**  | powershell script to deploy the ARM template **04-vnet-peering.json**     |
| **05-connection-monitor.json** | ARM template to deploye Azure connection monitor with multiple tests          |
| **05-connection-monitor.ps1**  | powershell script to deploy the ARM template **05-connection-monitor.json**   |

<ins>**Before running customize the values of variables in the powershell scripts**</ins>

<br>

**02-vnet1-vms.json**: by custom script extension (_"Microsoft.Compute/virtualMachines/extensions"_) are installed the following agents:
```json
"publisher": "Microsoft.Azure.NetworkWatcher",
"type": "NetworkWatcherAgentWindows",
"typeHandlerVersion": "1.4",
"autoUpgradeMinorVersion": true


"publisher": "Microsoft.EnterpriseCloud.Monitoring",
"type": "MicrosoftMonitoringAgent",
"typeHandlerVersion": "1.0",
"autoUpgradeMinorVersion": true


"publisher": "Microsoft.Compute",
"type": "CustomScriptExtension",
"typeHandlerVersion": "1.9",
"autoUpgradeMinorVersion": true


"publisher": "Microsoft.Compute",
"type": "BGInfo",
"typeHandlerVersion": "2.1"
"autoUpgradeMinorVersion": true,
```

**03-vnet2-vms.json**: by custom script extension (_"Microsoft.Compute/virtualMachines/extensions"_) are installed the following agents:
```json
"publisher": "Microsoft.Azure.NetworkWatcher",
"type": "NetworkWatcherAgentLinux",
"typeHandlerVersion": "1.4",
"autoUpgradeMinorVersion": true


"publisher": "Microsoft.EnterpriseCloud.Monitoring",
"type": "OmsAgentForLinux",
"typeHandlerVersion": "1.7",
"autoUpgradeMinorVersion": true


"publisher": "Microsoft.Azure.Extensions",
"type": "CustomScript",
"typeHandlerVersion": "2.1",
"autoUpgradeMinorVersion": true,
```

After the deployment of two ARM templates, you can check the presence of agents in the Azure VMs:

```powershell
C:\> Get-AzVMExtension -ResourceGroupName SEA-Cust41 -VMName SEA-Cust41-VM01

ResourceGroupName       : SEA-Cust41
VMName                  : SEA-Cust41-VM01
Name                    : BGInfo
Location                : westus2
Etag                    : null
Publisher               : Microsoft.Compute
ExtensionType           : BGInfo
TypeHandlerVersion      : 2.1
Id                      : /subscriptions/AAAAA-BBB-CCCC-DDDD-FFFFFFFFFF/resourceGroups/SEA-Cust41/providers/Micro
                          soft.Compute/virtualMachines/SEA-Cust41-VM01/extensions/BGInfo
PublicSettings          :
ProtectedSettings       :
ProvisioningState       : Succeeded
Statuses                :
SubStatuses             :
AutoUpgradeMinorVersion : True
ForceUpdateTag          :
EnableAutomaticUpgrade  :

ResourceGroupName       : SEA-Cust41
VMName                  : SEA-Cust41-VM01
Name                    : iis_and_AllowICMPv4
Location                : westus2
Etag                    : null
Publisher               : Microsoft.Compute
ExtensionType           : CustomScriptExtension
TypeHandlerVersion      : 1.9
Id                      : /subscriptions/AAAAA-BBB-CCCC-DDDD-FFFFFFFFFF/resourceGroups/SEA-Cust41/providers/Micro
                          soft.Compute/virtualMachines/SEA-Cust41-VM01/extensions/iis_and_AllowICMPv4
PublicSettings          : {
                            "commandToExecute": "powershell.exe Install-WindowsFeature -name Web-Server
                          -IncludeManagementTools && powershell.exe remove-item 'C:\\inetpub\\wwwroot\\iisstart.htm'
                          && powershell.exe Add-Content -Path 'C:\\inetpub\\wwwroot\\iisstart.htm' -Value $('Hello
                          World from ' + $env:computername) && powershell.exe New-NetFirewallRule -Name
                          'allow_ICMPv4_in' -DisplayName 'Allow ICMPv4' -Direction Inbound -Action Allow -Enabled True
                          -Profile Any -Protocol ICMPv4"
                          }
ProtectedSettings       :
ProvisioningState       : Succeeded
Statuses                :
SubStatuses             :
AutoUpgradeMinorVersion : True
ForceUpdateTag          :
EnableAutomaticUpgrade  :

ResourceGroupName       : SEA-Cust41
VMName                  : SEA-Cust41-VM01
Name                    : NetworkWatcher
Location                : westus2
Etag                    : null
Publisher               : Microsoft.Azure.NetworkWatcher
ExtensionType           : NetworkWatcherAgentWindows
TypeHandlerVersion      : 1.4
Id                      : /subscriptions/AAAAA-BBB-CCCC-DDDD-FFFFFFFFFF/resourceGroups/SEA-Cust41/providers/Micro
                          soft.Compute/virtualMachines/SEA-Cust41-VM01/extensions/NetworkWatcher
PublicSettings          :
ProtectedSettings       :
ProvisioningState       : Succeeded
Statuses                :
SubStatuses             :
AutoUpgradeMinorVersion : True
ForceUpdateTag          :
EnableAutomaticUpgrade  :

ResourceGroupName       : SEA-Cust41
VMName                  : SEA-Cust41-VM01
Name                    : OMSExtension
Location                : westus2
Etag                    : null
Publisher               : Microsoft.EnterpriseCloud.Monitoring
ExtensionType           : MicrosoftMonitoringAgent
TypeHandlerVersion      : 1.0
Id                      : /subscriptions/AAAAA-BBB-CCCC-DDDD-FFFFFFFFFF/resourceGroups/SEA-Cust41/providers/Micro
                          soft.Compute/virtualMachines/SEA-Cust41-VM01/extensions/OMSExtension
PublicSettings          : {
                            "workspaceId": "YYYYYYYY-VVVVVV-WWWW-ZZZZZZZZ"
                          }
ProtectedSettings       :
ProvisioningState       : Succeeded
Statuses                :
SubStatuses             :
AutoUpgradeMinorVersion : True
ForceUpdateTag          :
EnableAutomaticUpgrade  :



C:\> Get-AzVMExtension -ResourceGroupName SEA-Cust41 -VMName SEA-Cust41-VM03

ResourceGroupName       : SEA-Cust41
VMName                  : SEA-Cust41-VM03
Name                    : installcustomscript
Location                : westus2
Etag                    : null
Publisher               : Microsoft.Azure.Extensions
ExtensionType           : CustomScript
TypeHandlerVersion      : 2.1
Id                      : /subscriptions/AAAAA-BBB-CCCC-DDDD-FFFFFFFFFF/resourceGroups/SEA-Cust41/providers/Micro
                          soft.Compute/virtualMachines/SEA-Cust41-VM03/extensions/installcustomscript
PublicSettings          : {
                            "commandToExecute": "yum install -y httpd && systemctl enable httpd && systemctl start
                          httpd"
                          }
ProtectedSettings       :
ProvisioningState       : Succeeded
Statuses                :
SubStatuses             :
AutoUpgradeMinorVersion : True
ForceUpdateTag          :
EnableAutomaticUpgrade  :

ResourceGroupName       : SEA-Cust41
VMName                  : SEA-Cust41-VM03
Name                    : NetworkWatcher
Location                : westus2
Etag                    : null
Publisher               : Microsoft.Azure.NetworkWatcher
ExtensionType           : NetworkWatcherAgentLinux
TypeHandlerVersion      : 1.4
Id                      : /subscriptions/AAAAA-BBB-CCCC-DDDD-FFFFFFFFFF/resourceGroups/SEA-Cust41/providers/Micro
                          soft.Compute/virtualMachines/SEA-Cust41-VM03/extensions/NetworkWatcher
PublicSettings          :
ProtectedSettings       :
ProvisioningState       : Succeeded
Statuses                :
SubStatuses             :
AutoUpgradeMinorVersion : True
ForceUpdateTag          :
EnableAutomaticUpgrade  :

ResourceGroupName       : SEA-Cust41
VMName                  : SEA-Cust41-VM03
Name                    : OMSExtension
Location                : westus2
Etag                    : null
Publisher               : Microsoft.EnterpriseCloud.Monitoring
ExtensionType           : OmsAgentForLinux
TypeHandlerVersion      : 1.7
Id                      : /subscriptions/AAAAA-BBB-CCCC-DDDD-FFFFFFFFFF/resourceGroups/SEA-Cust41/providers/Micro
                          soft.Compute/virtualMachines/SEA-Cust41-VM03/extensions/OMSExtension
PublicSettings          : {
                            "workspaceId": "YYYYYYYY-VVVVVV-WWWW-ZZZZZZZZ"
                          }
ProtectedSettings       :
ProvisioningState       : Succeeded
Statuses                :
SubStatuses             :
AutoUpgradeMinorVersion : True
ForceUpdateTag          :
EnableAutomaticUpgrade  :
```

The Log analytics shows the connections with the Azure VMs:

[![2]][2]

Communication between the OMS agent and Log Anaytics can be done through the Log Analytics query:

```console
Heartbeat
| where Computer == "SEA-ER-41-VM01"
| sort by TimeGenerated desc
```

| Query                                                               | description                           |       
| ------------------------------------------------------------------- |:------------------------------------- |
| Heartbeat \| distinct Computer                                    	| total number of agents                |
| Heartbeat \| summarize AggregatedValue = dcount(Computer) by OSType | number of agents over time by OS type |
| Heartbeat \| summarize AggregatedValue = dcount(Computer) by Version | Distribution by agent version        |

Total number of agents connected to the Log Analytics workspace is visible also in Azure management portal:

[![3]][3]

[![4]][4]


## <a name="manual installation of OMS agent"></a>2. Install the OMS agent manually in on-premises Linux VM
The Log Analytics agent (OMS agent) for Linux (64 bit) is available in github at following link: 
<br>

[Download Latest OMS Agent for Linux (64-bit)](https://github.com/microsoft/OMS-Agent-for-Linux/releases/download/OMSAgent_v1.14.9-0/omsagent-1.14.9-0.universal.x64.sh)

Download the package in the linux VM on-premises and install the package by the command:
```bash
wget https://github.com/microsoft/OMS-Agent-for-Linux/releases/download/OMSAgent_v1.14.9-0/omsagent-1.14.9-0.universal.x64.sh
sudo sh ./omsagent-*.universal.x64.sh --install -w <WorkspaceID> -s <WorkspaceKey>
```
* \<WorkspaceID>: it is the workspace Id created by the **01-log-analytics.json**
* \<WorkspaceKey>: it is the workspace key associated to \<WorkspaceID>

## <a name="Connection Monitor"></a>3. Azure Connection Monitor
The connection monitor is configured with purpose to check out the CPU consumption of agent running in CentOS 7 Azure VM.

<br>

The deployment is shown below:

[![5]][5]

The diagram shows a graphical view of connection monitor tests: a single group is created with source in SEA-CUST41-vm03 and destination the other VMs (SEA-Cust41-VM01,SEA-Cust41-VM02,SEA-Cust41-VM04, SEA-Cust41-VM01).

[![6]][6]

## <a name="CPU utilization in linux VM"></a>4. CPU utilization in linux VM
The linux VMs in vnets have the **Standard_B2s** SKU. The logs below provide evidence that OMS agent and Network Watcher agent do not have significative impact on CPU utilization. 

[![7]][7]

[![8]][8]

[![9]][9]

```console
[root@SEA-Cust41-VM03 ~]# sar 1
Linux 3.10.0-957.27.2.el7.x86_64 (SEA-Cust41-VM03)      04/03/2022      _x86_64_        (2 CPU)

08:15:48 PM     CPU     %user     %nice   %system   %iowait    %steal     %idle
08:15:49 PM     all      1.51      0.00      1.51      0.00      0.00     96.98
08:15:50 PM     all      1.00      0.00      1.00      0.00      0.00     98.00
08:15:51 PM     all      0.00      0.00      0.00      0.00      0.00    100.00
08:15:52 PM     all      0.50      0.00      0.00      0.00      0.00     99.50
08:15:53 PM     all      0.00      0.00      0.50      0.00      0.00     99.50
08:15:54 PM     all      0.00      0.00      0.00      0.00      0.00    100.00
08:15:55 PM     all      1.50      0.00      1.00      0.00      0.00     97.50
08:15:56 PM     all      0.00      0.00      0.50      0.00      0.00     99.50
08:15:57 PM     all      1.50      0.00      0.00      0.00      0.00     98.50
08:15:58 PM     all      0.00      0.00      0.00      0.00      0.00    100.00
08:15:59 PM     all      0.00      0.00      0.00      0.00      0.00    100.00
08:16:00 PM     all      0.00      0.00      0.50      0.00      0.00     99.50
08:16:01 PM     all      0.50      0.00      0.50      0.00      0.00     98.99
08:16:02 PM     all      0.50      0.00      0.50      0.00      0.00     99.00
08:16:03 PM     all      0.00      0.00      0.00      0.00      0.00    100.00
08:16:04 PM     all      1.01      0.00      1.52      0.00      0.00     97.47
08:16:05 PM     all      1.00      0.00      1.00      0.00      0.00     98.00
08:16:06 PM     all      0.50      0.00      0.00      0.00      0.00     99.50
08:16:07 PM     all      0.50      0.00      1.51      0.00      0.00     97.99
08:16:08 PM     all      0.50      0.00      0.00      0.00      0.00     99.50
08:16:09 PM     all      0.00      0.00      0.00      0.00      0.00    100.00
08:16:10 PM     all      0.00      0.00      0.50      0.00      0.00     99.50
08:16:11 PM     all      0.50      0.00      0.00      0.00      0.00     99.50
08:16:12 PM     all      0.00      0.00      0.50      0.00      0.00     99.50
08:16:13 PM     all      1.01      0.00      0.50      0.00      0.00     98.49
08:16:14 PM     all      0.00      0.00      0.00      0.00      0.00    100.00
08:16:15 PM     all      0.00      0.00      0.50      0.00      0.00     99.50
08:16:16 PM     all      0.50      0.00      0.50      0.00      0.00     99.00
08:16:17 PM     all      0.00      0.00      0.00      0.00      0.00    100.00
08:16:18 PM     all      0.50      0.00      0.00      0.00      0.00     99.50
08:16:19 PM     all      0.50      0.00      0.50      0.00      0.00     98.99
08:16:20 PM     all      2.00      0.00      1.00      0.00      0.00     97.00
08:16:21 PM     all      1.01      0.00      1.01      0.00      0.00     97.99
08:16:22 PM     all      0.50      0.00      0.50      0.00      0.00     98.99
08:16:23 PM     all      0.00      0.00      0.00      0.00      0.00    100.00
08:16:24 PM     all      0.00      0.00      0.50      0.00      0.00     99.50
08:16:25 PM     all      1.51      0.00      0.50      0.00      0.00     97.99
08:16:26 PM     all      0.50      0.00      0.50      0.50      0.00     98.49
08:16:27 PM     all      0.50      0.00      0.00      0.00      0.00     99.50
08:16:28 PM     all      0.00      0.00      0.50      0.00      0.00     99.50
08:16:29 PM     all      0.00      0.00      0.00      0.00      0.00    100.00
08:16:30 PM     all      0.00      0.00      0.50      0.00      0.00     99.50
08:16:31 PM     all      1.00      0.00      1.00      0.00      0.00     98.00
08:16:32 PM     all      0.00      0.00      0.00      0.00      0.00    100.00
08:16:33 PM     all      0.50      0.00      0.00      0.00      0.00     99.50
08:16:34 PM     all      0.00      0.00      0.50      0.00      0.00     99.50
08:16:35 PM     all      0.00      0.00      0.00      0.00      0.00    100.00

```

## <a name="Log analytics workspace"></a>5. NOTE about Log analytics workspace**
Log analytics workspace name uniqueness is per resource group. <br>
It allows you to use the same workspace name in deployments across multiple environments for consistency. Workspace uniqueness is maintained as follow:
* Workspace ID – global uniqueness remained unchanged.
* Workspace resource ID – global uniqueness.
* Workspace name – per resource group

<!--Image References-->

[1]: ./media/network-diagram1.png "network diagram"
[2]: ./media/vm-agents.png "network diagram"
[3]: ./media/logAnalytics1.png "Windows OS connected to the Log Analytics workspace"
[4]: ./media/logAnalytics2.png "Linux OS connected to the Log Analytics workspace"
[5]: ./media/connection-monitor1.png "Connection monitor"
[6]: ./media/connection-monitor2.png "connection monitor"
[7]: ./media/cpu01.png "CPU utilization in linux VM"
[8]: ./media/cpu02.png "CPU utilization in linux VM"
[9]: ./media/cpu03.png "CPU utilization in linux VM"

<!--Link References-->

