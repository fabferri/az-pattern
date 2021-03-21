<properties
pageTitle= 'Azure Ubuntu VMs with cloud-init customization'
description= "ARM template to create a Linux VM"
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
   ms.date="21/03/2021"
   ms.author="fabferri" />

# How to use cloud-init in Azure VM 
In Microsoft Azure VM we have a feature called custom data. Custom data is sent to the VM along with the other provisioning configuration information.
Currently, only a limited number of image in the Microsoft Azure Gallery have cloud-init preinstalled and configured to act on the custom data sent during provisioning See more information [cloud-init support for VM in Azure](https://docs.microsoft.com/en-us/azure/virtual-machines/linux/using-cloud-init)

This means that for cloud-init image ready, you can use custom data to provision a VM using a cloud-init configuration file.


**Project files**
| folder\file               | Description                                                                        |
| ------------------------- | ---------------------------------------------------------------------------------- |
| .\pws\cloud-init.txt      | cloud-init file used with **vm.ps1**                                               |
| .\pws\vm.ps1              | Create a VM by powershell script and apply a provision time the cloud-init config  |
|                           |                                                                                    |
| .\template\cloud-init.txt |  cloud-init file used with **vms.json**                                            |
| .\temlate\vms.json        | ARM template to create multiple VMs and apply to each VM the cloud-init config     |
| .\temlate\vms.json        | ARM template to create multiple VMs and apply to each VM the cloud-init config     |

In Microsoft Azure Powershell cmdlet 
```powershell
Set-AzVMOperatingSystem -VM $vm_Config -Linux -ComputerName $vmName -Credential $vmCreds -CustomData $cloudInitContent 
```
the $cloudInitContent is the content of the text file cloud-init.txt. 
Note in powershell the CustomData contenxt is passed as string not base-64 encoded.


In ARM template the cloud-init is passed into the resource **"Microsoft.Compute/virtualMachines"** in the object **"customData"** :
```json
"osProfile": {
          "computerName": "[variables('vmArray')[copyIndex()].vmName]",
          "adminUsername": "[variables('adminUsername')]",
          "adminPassword": "[variables('adminPassword')]",
          "customData" : "[variables('customData')]"
        },
``` 
The object **"customData"** specifies a base-64 encoded string of cloud-init file. The base-64 encoded string is decoded to a binary array that is saved as a file on the Azure VM. The maximum length of the binary array is 65535 bytes. The only limit here is that the encoded file must be less than 64KB or the Azure API will not accept the request.

In our example the **cloud-init.txt**:
```console
#cloud-config
package_upgrade: true
packages:
  - nginx
runcmd:
  - service nginx restart
```

The very basic file install and start nginx web server in the Azure VMs.


<!--Image References-->



<!--Link References-->

