<properties
pageTitle= 'VNet NAT'
description= "VNet NAT wit ARM template"
documentationcenter: na
services="networking"
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
   ms.date="26/02/2020"
   ms.author="fabferri" />

## Azure ARM template to deploy and test VNet NAT 

Azure Virtual Network offers network address translation (NAT) to simplify outbound-only internet connectivity for virtual networks (VNets). All outbound connectivity uses the public IP address and/or public IP prefix resources connected to the virtual network NAT. Outbound connectivity is possible without a load balancer or public IP addresses directly attached to virtual machines. VNet NAT (preview) is fully managed, highly resilient.
In summary:
*	A NAT gateway supports up to 16 IPs total, up to (60,000*16=) 1M  SNAT ports on-demand
*	Idle-timeout [4min, 120min]
*	NAT takes precedence over other outbound scenarios and replaces the default Internet destination of a subnet.
*	Multiple subnets can use same NAT Gateway. 
*	Multiple NAT Gateways can exist within same VNet.
*	It is possible to combine inbound and outbound scenario in the same subnet through different resources (VNet NAT and external load balancer) because the service is aware in which direction you originate the flow.
*	NAT Gateway supports zoning


### <a name="NetworkDiagram"></a>1. Network diagram
The network configuration is based on two VNets, vnet1 and vnet2.

A NAT gateway is associated with the subnet1 in vnet1.

A single public IP and public prefix /31 is associated with the NAT gateway to manage the SNAT.
The vnet2 has three VMs, each with public IP.

[![1]][1]

All the VMs are deployed with:
*	Standard_D2_v2 (2 vcpus, 7 GiB memory) SKU
*	Windows 2019
The vm2 in vnet1 is used as jump box to access to the [vnet1-vm1,vnet1-vm3, vnet1-vm4].

A good number of SNAT flows through the NAT Gateway can be established by two applications written in C#:

*	**server.exe** (receiver role) accepts incoming connections from a remote client on local custom port (i.e. TCP port 6000).
*	**client.exe** (sender role) uses .NET tasks to open multiple TCP sockets in parallel and send a small amount of data (datetime, local IP, local TCP port, thread ID) to a remote receiver.

The NAT gateway support SNAT outboud, with TCP sessions initilized from the internal VMs to internet.  In our network configuration the receivers run in the VMs of vnet2, the senders run in the VMs of vnet1.  

> *Note*
>
> Before running **nat-gw.ps1**  and **vm.ps1** set the input variables:
>
> $adminUsername: administrator username of the Azure VMs
>
> $adminPassword: administrator password of the Azure VMs
>
> $subscriptionName : name of the Azure subscription
>
> $location         : name of the Azure region
>
> $rgName           : name of the Azure resource group
>

### <a name="filedescription"></a>2. files description

| file /folder        | Description                                                               |
| ------------------- |:--------------------------------------------------------------------------|
| **nat-gw.json**     | powershell script to deploy the Azure ARM template  **nat-gw.json**       |
| **nat-gw.json**     | ARM template to create vnet1 with VMs and NAT Gateway                     |
| **vm.ps1**          | powershell script to deploy the Azure ARM template  **vm.json**           |
| **vm.json**         | Azure ARM template to create vnet2 with VMs                               |
| **code**            | folder with C# source code for the applications **server.exe, client.exe**|

Below the steps to run the test.

### <a name="EnableNATGateway"></a>3. Enable the Azure subscription to the NAT Gateway public preview

```console
PS C:\> Register-AzProviderFeature -ProviderNamespace Microsoft.Network -FeatureName AllowNatGateway

FeatureName     ProviderName      RegistrationState
-----------     ------------      -----------------
AllowNatGateway Microsoft.Network Registering      


PS C:\> get-AzProviderFeature -ProviderNamespace Microsoft.Network -FeatureName AllowNatGateway

FeatureName     ProviderName      RegistrationState
-----------     ------------      -----------------
AllowNatGateway Microsoft.Network Registering      


PS C:\ > get-AzProviderFeature -ProviderNamespace Microsoft.Network -FeatureName AllowNatGateway

FeatureName     ProviderName      RegistrationState
-----------     ------------      -----------------
AllowNatGateway Microsoft.Network Registered       

```
### <a name="NET Core 3.1 runtime"></a>4. Install NET Core 3.1 Desktop Runtime (v3.1.2) - Windows x64 

The applications (server.exe and client.exe) require .NET core; the x64 runtime can be downloaded at link:
https://dotnet.microsoft.com/download?missing_runtime=true&arch=x64&rid=win10-x64

.NET core runtime library is required on the VMs with sender role and receiver role.

### <a name="NSG"></a>5. Add a security rule to the NSG attached to the subnet1 of the vnet2

To enable the incoming TCP traffic to the Azure VMs (receivers), a security rule has to be added in the NSG associated with the vnet2, to accept incoming connection on the specific  TCP port used by **server.exe**.

### <a name="WindowsFirewall"></a>6. Add the rule on the Windows firewall in the vm3
Create a security rule in Windows firewall of VMs (receiver) in vnet2 to accept incoming call on specific ports (i.e. 6000-6100).

### <a name="runApplication"></a>7. Run multiple TCP flows between VMs (senders) in vnet1 and VMs (receivers) in vnet2

To run multiple TCP flows, in each VM with sender role are opened one or more console sessions.
In each console session is executed the **client.exe** application, spinning up multiple .NET tasks.
Each .Net task in the **client.exe** opens a socket with receiver.

Syntax to run the application:

```console
client.exe <pubIP_Receiver> <TCP_port_receiver> <NumberTasks> <frequency sending data in msec>

server.exe  <TCP_local_port> 
```
[![2]][2]

Below the workout with multiple senders [vnet1-vm1, vnet1-vm3, vnet1-vm4] and multiple receivers [vnet2-vm3, vnet2-vm4, vnet2-vm5].

```console
vnet2-vm3 (receiver) with public IP: 20.186.177.230
vnet2-vm3 (receiver) console: server.exe 6010

vnet1-vm1 (sender) console1: client.exe 20.186.177.230 6000 100 90000
vnet1-vm1 (sender) console2: client.exe 20.186.177.230 6000 100 90000
vnet1-vm1 (sender) console3: client.exe 20.186.177.230 6000 100 90000

Total number of TCP flow created: 300 between vnet1-vm1 (sender) and vnet2-vm3 (receiver).
```

```console
vnet2-vm4 (receiver) with public IP:  52.177.125.18
vnet2-vm4 (receiver) console: server.exe 6010

vnet1-vm3 (sender) console1: client.exe 52.177.125.18 6010 100 90000
vnet1-vm3 (sender) console2: client.exe 52.177.125.18 6010 100 90000
vnet1-vm3 (sender) console3: client.exe 52.177.125.18 6010 100 90000

Total number of TCP flow created: 300 between vnet1-vm3 (sender) and vnet2-vm4 (receiver). 
```

```console
vnet2-vm5 (receiver) with public IP: 52.177.121.75
vnet2-vm5 (receiver) console: server.exe 6020

vnet1-vm4 (sender) console1: client.exe 52.177.121.75 6020 100 90000
vnet1-vm3 (sender) console2: client.exe 52.177.121.75 6020 100 90000
vnet1-vm3 (sender) console3: client.exe 52.177.121.75 6020 100 90000

Total number of TCP flow created: 300 between vnet2-vm5 (receiver) and vnet1-vm3 (sender)
```
In total 3*(300 TCP flows/VM)=600 TCP flows.

The number of .Net tasks in each client.exe can be increased if an higher number of flows are required.

### <a name="runApplication"></a>7. Checking the total number of TCP connections through the NAT gateway

The total number of total TCP connections can be checked out by powershell command **Get-NetTCPConnection** in the receivers [vnet2-vm3 (receiver), vnet2-vm4 (receiver), vnet2-vm5 (receiver)] :

in vnet2-vm3 (receiver): PS C:\> Get-NetTCPConnection -LocalPort 6000 | Measure-Object –Line
in vnet2-vm4 (receiver): PS C:\> Get-NetTCPConnection -LocalPort 6010 | Measure-Object –Line
in vnet2-vm5 (receiver): PS C:\> Get-NetTCPConnection -LocalPort 6020 | Measure-Object –Line 

The same information can be carve out by command line **netstat -an -p TCP** :

```console
netstat -ano | findstr :6000
netstat -ano | findstr :6000 | findstr ESTABLISHED

```

## <a name="clientBypowershell"></a>8. how to run executable file with powershell
vnet1-vm3 (sender) console1: client.exe 52.177.125.18 6010 100 90000

The sender client.exe can be run by powershell job:

```console
$IPServer = "52.177.125.18"
$port="6010"
$numTasks="100"
$sendingFrequency="900000"
Write-Host $formatFile -ForegroundColor Yellow
Write-Host $cmd -ForegroundColor Yellow

for ($i=0; $i -lt 3; $i++) {
 try{
     $cmd = "C:\netcoreapp3.1\client.exe $IPServer $port $numTasks $sendingFrequency"
     Invoke-Expression $cmd
  } catch {
     write-host "Invoke Expression1 failed..." -ForegroundColor Yellow
  }
}
``` 
or in interactive way:

```console
$IPServer = "52.177.125.18"
$port="6010"
$numTasks="100"
$sendingFrequency="900000"
Write-Host $formatFile -ForegroundColor Yellow
Write-Host $cmd -ForegroundColor Yellow

for ($i=0; $i -lt 3; $i++) {
 try{
     $cmd = "C:\netcoreapp3.1\client.exe $IPServer $port $numTasks $sendingFrequency"
     Invoke-Expression $cmd
  } catch {
     write-host "Invoke Expression1 failed..." -ForegroundColor Yellow
  }
}
```
<!--Image References-->

[1]: ./media/network-diagram.png "network diagram"
[2]: ./media/tcp-connections.png "network diagram"


<!--Link References-->

