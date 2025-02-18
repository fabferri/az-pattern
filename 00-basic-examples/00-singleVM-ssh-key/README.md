<properties
pageTitle= 'Linux VM with ssh key authetication and Azure Bastion'
description= "Linux VM with ssh key authetication and Azure Bastion"
documentationcenter: na
services="Azure LinuxVM, SSH KEY"
documentationCenter="[gitub](https://github.com/fabferri)"
authors="fabferri"
editor="fabferri"/>

<tags
   ms.service="configuration-Example-Azure"
   ms.devlang="na"
   ms.topic="Azure networking"
   ms.tgt_pltfrm="Azure"
   ms.workload="Azure LinuxVM with SSH key, Azure Bastion"
   ms.date="18/01/2025"
   ms.author="fabferri" />

## Linux VM with ssh key authetication and Azure Bastion

The ARM template creates a linux VM with ssh key authetication. In the Azure VNet is deployed Azure Bastion to connect to the VM. The network diagram is shown below: 

[![1]][1]

The  Linux VM has a public IP to connect in SSH to the VM without transit through the Azure Bastion. <br>
Before running the script an SSH key needs to be generated. By git bash command:
```bash
ssh-keygen -m PEM -t rsa -b 4096  -f ./vmkey.pem
```
The ssh-keygen generated in local folder the private key named **vmkey.pem** in PEM format and a public key named **vmkey.pem.pub** <br>
The file **init.json** contains a list of input variables. <br>
```json
{
    "subscriptionName": "AZURE_SUBSCRIPTION",
    "resourceGroupName": "RESOURCE_GROUP_NAME",
    "location": "AZURE_REGION",
    "adminUsername": "ADMINISTRATOR_USERNAME",
    "adminPublicKey": "PUBLIC_SSH_KEY"
}
```

Open the public key **vmkey.pem.pub** and paste the content in the variable **adminPublicKey** in **init.json**<br>
After setting the variables in **init.json**, you can start the deployment through the script **vmsshkey.ps1**


> [!NOTE]
>
> if you want to add a comment to the public key you can use the command: <br>
> <b>ssh-keygen -m PEM -t rsa -b 4096 -C "by-gitcommand" -f ./vmkey.pem</b> <br>
>
> -b flag determines the key length <br> 
> -C provides a comment <br>
>

Since the public ssh key is part of the private ssh key, we can extract the public key from the private; to do this we use the ssh-keygen command:
```bash
ssh-keygen -y  -f ./vmkey.pem
```
-y : this option will read a private OpenSSH format file and print an OpenSSH public key to stdout. <br>

To display the fingerprint and RCA length of specified public key file use the option -l: 
```bash
ssh-keygen -l  -f ./vmkey.pem.pub
```

To exact only the fingerprint:
```bash
ssh-keygen -l -f ./vmkey.pem.pub | cut -d ' ' -f 2
```

`Tag: SSH key` <br>
`date: 18-02-2025`

<!--Image References-->

[1]: ./media/network-diagram.png "network diagram"

<!--Link References-->

