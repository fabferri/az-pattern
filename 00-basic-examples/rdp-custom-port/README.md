<properties
pageTitle= 'RDP with custom port in Windows VMs'
description= "RDP with custom port in Windows VMs"
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
   ms.workload="RDP, custom script extension"
   ms.date="18/07/2022"
   ms.review=""
   ms.author="fabferri" />

# RDP with custom port in Windows VMs
The network diagram is shown below:

[![1]][1]

* The ARM template uses custom script extension to change the listening port for Remote Desktop (RDP) in Azure vm1 and vm2
* the custom script extension create an inbound security rules to accept incoming connection on custom RDP port and ICMP echo
 

To change the listening port for RDP:
```powershell
$portvalue = 3390

Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp' -name "PortNumber" -Value $portvalue 

New-NetFirewallRule -DisplayName 'RDPPORTLatest-TCP-In' -Profile 'Any' -Direction Inbound -Action Allow -Protocol TCP -LocalPort $portvalue 
New-NetFirewallRule -DisplayName 'RDPPORTLatest-UDP-In' -Profile 'Any' -Direction Inbound -Action Allow -Protocol UDP -LocalPort $portvalue 
```
The command **Set-ItemProperty** add a new RDP Port to the windows registry.
In windows firewall the profile **Any** sets the security rules in all profiles: **Private** and **Public**. <br>
The powershell command also accepts a list of profiles:

```powershell
$portvalue = 3390

Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp' -name "PortNumber" -Value $portvalue 

New-NetFirewallRule -DisplayName 'RDPPORTLatest-TCP-In' -Profile  @('Private', 'Public') -Direction Inbound -Action Allow -Protocol TCP -LocalPort $portvalue 
New-NetFirewallRule -DisplayName 'RDPPORTLatest-UDP-In' -Profile @('Private', 'Public') -Direction Inbound -Action Allow -Protocol UDP -LocalPort $portvalue 
```

The same script extension enables the ICMP echo reply:
```powershell
New-NetFirewallRule -DisplayName 'Allow ICMPv4' -Profile Any -Name Allow_ICMPv4_in -Direction Inbound -Action Allow -Protocol ICMPv4 -Enabled True 
``` 

## <a name="list of files"></a>2. File list

| File name            | Description                                                                    |
| -------------------- | ------------------------------------------------------------------------------ |
| **az.json**          | ARM template to create vnet adn the two Windows server 2022 VMs with custom RDP port number |
| **az.ps1**           | powershell script to deploy the ARM template **az.json**. The script read the values of input variables in **init.json**  |
| **init.json**        | list of input variables |

Before running, edit the values in the **init.json**
```json
{
    "subscriptionName": "AZURE_SUBSCRIPTION_NAME",
    "ResourceGroupName": "RESOURCE_GROUP_NAME",
    "location": "AZURE_REGION",
    "adminUsername": "ADMINISTRATOR_USERNAME",
    "adminPassword": "ADMINISTRATOR_PASSWORD",
    "customRDPportvm1": XXXXX,
    "customRDPportvm2": YYYYY,
    "mngIP": ""
}
```
* **"customRDPportvm1"**: value of custom RDP port for the vm1
* **"customRDPportvm1"**: value of custom RDP port for the vm2

Inside the VM, you can check the current RDP port by running the following PowerShell command:
```powershell
Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp' -name 'PortNumber'


PortNumber   : <custom_port_number>
PSPath       : Microsoft.PowerShell.Core\Registry::HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Terminal 
               Server\WinStations\RDP-Tcp
PSParentPath : Microsoft.PowerShell.Core\Registry::HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations
PSChildName  : RDP-Tcp
PSDrive      : HKLM
PSProvider   : Microsoft.PowerShell.Core\Registry
```

The custom RDP port is shown in the listening ports:
```console
netstat -na | find "LISTENING"
```

`Tags: RDP, custom script extension`
`date: 18-07-22`

<!--Image References-->

[1]: ./media/network-diagram.png "network diagram"

<!--Link References-->

