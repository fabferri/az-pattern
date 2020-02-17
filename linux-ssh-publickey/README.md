<properties
pageTitle= 'Connect to Azure Linux VMs through public key authetication method'
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
   ms.date="16/02/2020"
   ms.author="fabferri" />

## Connect in SSH to Azure Linux VM by public key authetication method 
SSH offers several options for user authentication and the most common ones are passwords and public key authentication methods. The principle of public key is to have a cryptographic key pair, public key and private key, where the public key is configured on the server to authorize access to every SSH client who has a copy of the private key.

Windows machines allow you to use native tools to establish a SSH connection, but you need first to make sure that the feature Openssh windows client is installed. Normally is not installed by default so you will need first to do it. Go to Windows -> Settings -> Apps -> Manage optional feature 

[![1]][1]

and then add the feature "OpenSSH Client":

[![2]][2]

SSH operates on top of TCP port 22. Since SSH uses TCP as underlying protocol, there are two mechanisms to keep a ssh session alive: TCP Keepalives implemented at Linux/Unix kernel level and depends on kernel parameters to use keepalive timers and the ssh built-in **ServerAliveInterval** setting.
Both TCP Keepalives and SSH **ServerAliveInterval** packets are generated to refresh the TCP connection  along the path between server and client. The difference between the two is that TCP Keepalives are simple, unencrypted packets that can be spoofed, while the **ServerAliveInterval** packets are sent on the ssh encrypted channel and cannot be spoofed.
To prevent SSH sessions from becoming idle and hung or to get disconnected due to timeout is to edit  the ssh configuration file **$HOME\.ssh\config** and define the declarations:

* **ServerAliveInterval**: number of seconds that the client will wait, after which if no data has been received from the server, ssh will send a message through the encrypted channel to request a response from the server, to keep the connection alive.
* **ServerAliveCountMax**: Sets the number of server alive messages which may be sent without ssh receiving any messages back from the server. If this threshold is reached while server alive messages are being sent, ssh will disconnect from the server, terminating the session.

The SSH configuration file has a declarion for MAC (**M**essage **A**uthetication **C**ode) specifies algorithms in order of preference used for data integrity protection. Multiple algorithms must be comma-separated.

User keys are managed on the ssh client: you have to create a key pair consisting of your public key **id_rsa.pub** and your private key **id_rsa**. Those keys are stored in the client, under $HOME\.ssh\

The powershell **generate-keys.ps1** checks if the file $HOME\.ssh\id_rsa exists; if it doesn't, the following ssh command generates the keys:

```console
ssh-keygen.exe -t rsa -b 2048 -f "$HOME\.ssh\$FileName"
```


#### <a name="ssh"></a>2. Connect to the azure VM by SSH
To connect to the Azure VM use the command:
```console
ssh <username>@<publicIP_AzureVM>
```
where:

*username*: it is the username to login in the VM

*publicIP_AzureVM*: it is the public IP to access to the VM

> Note
>
>  do not run the ssh command in powershell ISE, it doesn't work.
>

#### <a name="ssh"></a>3. Files summary

| file             | Description                                  |
| ---------------- |:---------------------------------------------|
| generate-keys.ps1| generate the privare and public keys         |
| vm.ps1           | powershell to deploy Azure VM with public key|
| vm.json          | ARM template to create Azure VM              |


<!--Image References-->

[1]: ./media/windows-optional-features.png "windows 10 optional features"
[2]: ./media/open-ssh-client.png "OpenSSH client"

<!--Link References-->

