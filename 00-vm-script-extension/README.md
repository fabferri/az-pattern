<properties
pageTitle= 'Azure VMs with custom script extension'
description= "Azure VMs with custom script extension"
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
   ms.date="09/04/2020"
   ms.author="fabferri" />

## Azure VMs with custom script extension

Custom script extensions execute scripts on Azure VMs for post deployment configuration, software installation, or any other configuration or management tasks.



### Linux command
Customization of Linux VM is done through the following command: 

```console

yum install -y httpd && systemctl enable httpd && systemctl start httpd && yum install -y epel-release && yum install -y iperf3 && yum install -y nload

```
The command is defined in the ARM template **vms-script-extension.json**, variable:"linuxCommand"
The command install httpd daemon, set the EPEL repository, install iperf3 and nload (tool to monitor the traffic in the network adapter) 

### Windows command
Customization of Windows VM is done through the following command: 

```console

powershell.exe Install-WindowsFeature -name Web-Server -IncludeManagementTools && powershell.exe remove-item 'C:\\inetpub\\wwwroot\\iisstart.htm' && powershell.exe Add-Content -Path 'C:\\inetpub\\wwwroot\\iisstart.htm' -Value $('Hello World from ' + $env:computername) && powershell.exe New-NetFirewallRule -Name 'allow_ICMPv4_in' -DisplayName 'Allow ICMPv4' -Direction Inbound -Action Allow -Enabled True -Profile Any -Protocol ICMPv4

```
The command is defined in the ARM template **vms-script-extension.json**, variable:"windowsCommand"
The command install IIS and set the windows firewall rule to accept inbound ICMP traffic

> [!NOTE]
> In powershell script **vms-script-extension.ps1** set the following variables:
> * **$subscriptionName**:  Azure subscription name 
> * **$adminUsername**: administrator username of the Azure VMs
> * **$adminPassword**: administrator password of the Azure VMs
> *






<!--Image References-->


<!--Link References-->

