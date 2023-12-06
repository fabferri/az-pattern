<properties
pageTitle= 'Azure Cloud Shell'
description= "Azure Cloud Shell"
services="Azure"
documentationCenter="https://github.com/fabferri/"
authors="fabferri"
editor=""/>

<tags
   ms.service="configuration-Example-Azure"
   ms.devlang="bash"
   ms.topic="article"
   ms.tgt_pltfrm="Azure"
   ms.workload="Azure"
   ms.date="06/12/2023"
   ms.author="fabferri" />

# Azure Cloud Shell
Azure Cloud Shell is an interactive, authenticated, browser-accessible terminal for managing Azure resources. You can spin up the Azure Cloud Shell from Azure Management portal:

[![1]][1]

Cloud Shell allocates machines on a per-request basis and as a result machine state doesn't persist across sessions. To persist files across sessions, on first launch is attached an Azure file share. <br>
Cloud Shell creates three resources on your behalf in the supported region that's nearest to you:
- Resource group
- Storage account
- fileshare. The fileshare mounts as **$HOME\clouddrive** in your **$HOME** directory. This is a one-time action on first launch, and the fileshare mounts automatically in subsequent sessions. The fileshare also contains a 5-GB image that automatically persists data in your **$HOME** directory. Files outside of **$HOME** and machine state aren't persisted across sessions.

<br>

Cloud Shell persists files through both of the following methods:
- Creating a disk image of your **$HOME** directory to persist all contents within the directory. The disk image is saved in your specified fileshare as **acc_`<User>`.img** at **fileshare.storage.windows.net/fileshare/.cloudconsole/acc_`<User>`.img**, and it automatically syncs changes.
- Mounting your specified fileshare as clouddrive in your **$HOME directory** for direct file-share interaction. **/Home/`<User>`/clouddrive** is mapped to **fileshare.storage.windows.net/fileshare**. 

To discover which fileshare is mounted as clouddrive, run the **df** command.

## <a name="copy files to Cloud Shell storage"></a>1. Copy local files to the Cloud Shell storage 
It is possible to copy local files to a Cloud Shell file share using the button on the cloud shell menu: 

[![2]][2]

Moving bash script created in Windows to linux can cause an issue. <br>
Running the script it might help appear the messages like this: <br>

**-bash: '\r': command not found** <br>

Windows style for newline characters can cause issues. The error: <br>

**'\r': command not found**

is caused by shell not able to recognise Windows-like CRLF line endings (0d 0a) as it expects only LF (0a).

One way to fix the issue is to use the **dos2unix** command to modifies the file in place. <br>
Azure Cloud Shell does not have possibility to install packages, then the **dos2unix** command can't be installed. <br>
It is possibile in this case remove trailing **\r** character that causes this error:

```bash
sed -i 's/\r$//' filename
```

To remove '\r' in all files in current directory run<br/> 
```bash
for i in *; do if [[ -f $i ]]; then sed -i 's/\r$//' "$i"; fi; done
```

To run the bash script in Azure Cloud Shell: 
1. include at beginning of bash script file the statement:
```bash
#!/bin/bash
```
2. set the execution mode on the file:
```bash
chmod +x filename
```

## <a name="Copy a bash script to the Cloud Shell"></a>2. Copy a bash script to the Cloud Shell 
The bash script **create-vm.sh** creates an Azure Ubuntu VM by az CLI commands. <br>
in the script **create-vm.sh** replace the value of ADMINISTRATOR_USERNAME and ADMINISTRATOR_PASSWORD with your values: <br>

username='ADMINISTRATOR_USERNAME' <br>
adminPassword='ADMINISTRATOR_PASSWORD' <br>

Let assume you have copy the bash script **create-vm.sh** in your local Windows host. <br> 
Copy the script from your local Windows system to the Cloud Shell. <br>
In the Cloud Shell, remove the character '\r':
```bash
sed -i 's/\r$//' create-vm.sh
```

Make the bash script **create-vm.sh** executable [**chmod +x create-vm.sh**] and then run it:
```
./create-vm.sh
```

`Tags: Azure Cloud Shell` <br>
`date: 06-12-23` <br>

<!--Image References-->

[1]: ./media/cloud-shell.png "start Cloud Shell"
[2]: ./media/copying-files.png "copying local files to the Cloud Shell storage account"

<!--Link References-->
