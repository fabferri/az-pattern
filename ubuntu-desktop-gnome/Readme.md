<properties
pageTitle= 'Ubuntu VM with GNOME desktop'
description= "Ubuntu VM with Gnome desktop installed through customer script extension"
services="Ubuntu VM with GNOME desktop"
documentationCenter="https://github.com/fabferri/"
authors="fabferri"
editor=""/>

<tags
   ms.service="configuration-Example-Azure"
   ms.devlang="ARM template"
   ms.topic="article"
   ms.tgt_pltfrm="Azure"
   ms.workload="Ubuntu VM with GNOME desktop"
   ms.date="15/09/2022"
   ms.author="fabferri" />

# Ubuntu VM with GNOME desktop, Visual Studio Code and dotnet SDK
The ARM template deploys an Ubuntu server 20.04 and it uses custom script extension to install GNOME desktop and Remote desktop support via **xrdp**. 
The custom script extension installs the following components:
- ubuntu-desktop-minimal (minimal is a subset of all full Ubuntu desktop). GNOME is the default desktop environment for Ubuntu 20.04 Focal Fossa Linux.
- xrdp: it is a Remote Desktop Protocol (RDP) Server
- Visual Studio Code
- dotnet SDK (LTS)
- Microsoft Edge browser
- Chrome web browser

Runtime to execute the custom script extension is about 10 minutes. The full deployment of VM takes longer.

**Note:**<br>
When you connect to the VM via RDP, the desktop looks different from local login. The GNOME dock isn't present on the home screen and in GNOME desktop setting is not presente the **Appearance** option<br>
A way to solve the issue is to login in the VM and paste the following code in the file called **.xsessionrc** <br>
```bash
cat <<EOF > ~/.xsessionrc
export GNOME_SHELL_SESSION_MODE=ubuntu
export XDG_CURRENT_DESKTOP=ubuntu:GNOME
export XDG_CONFIG_DIRS=/etc/xdg/xdg-ubuntu:/etc/xdg
EOF
```
This file is a login script that will load your desktop configuration into the remote session. <br> 
After the file is created, login back to the xRDP session and see if the desktop looks like the one you have when logged on locally.

## <a name="List of files"></a>1. List of files 
| file                       | Description                                                               | 
| -------------------------- |-------------------------------------------------------------------------- | 
| **az-gnome.json**          | ARM template to deploy an ubuntu 20.04 VM and run custom script extension |
| **az-gnome.ps1**           | powershell script to deploy **az-gnome.json**                             |
| **gnome-vscode-dotnet.sh** | bash script to install Gnome, Visual Studio Code, .NET long terms support, Chrome web browser |

**NOTE:** <br>
- Before running the **az-gnome.ps1** customize the value of variables at the head of the script:
   - $adminUsername = "ADMINISTRATOR_USERNAME" 
   - $adminPassword = "ADMINISTRATOR_PASSWORD"
- The deployment has been tested successful with **Standard D2s v3** (2 vcpus, 8 GiB memory)


## <a name="custom script extension"></a>2. Check the correct installation
when the deployment is completed, it is good practice verifying the correct installation. <br>
Custom script extension logs are stored in:
```
root@vm1:~# ll /var/lib/waagent/custom-script/download/0/
root@vm1:~# cat /var/lib/waagent/custom-script/download/0/stderr
root@vm1:~# cat /var/lib/waagent/custom-script/download/0/stdout
root@vm1:~# cat /var/lib/waagent/custom-script/download/0/gnome-vscode-dotnet.sh
```

**xrdp** configuration files are:
```console
/usr/bin/xrdp
/etc/xrdp/xrdp.ini
/var/log/xrdp.log
/var/run/xrdp.pid
```
Connect in SSH to the VM and check the status of service:
```console
sudo sysctl status xrdpd
```

## <a name="check the version dotnet"></a>3. Check the versions
For more information about installing .NET 6 see the post [Installing .NET 6 on Ubuntu 22.04 (Jammy)](https://github.com/dotnet/core/issues/7699)
To check the dotnet SDK version:
```console
dotnet --version
```

To check the Microsoft Edge browser version, use the command: 
```
microsoft-edge --version
```
Launch the microsoft-edge from command prompt by the command:
```console
microsoft-edge
```

## <a name="Check the last reboot time"></a>4. Check the last reboot time
The **last reboot** command, which will display all the previous reboot date and time for the system. This picks the information from the **/var/log/wtmp** file.
```console
last reboot
```
To get the last shutdown time: 
```console
last shutdown
```

Use the **who -b** command which displays the last system reboot date and time.
```console
who -b
```

## <a name="Check the last reboot time"></a>3. Connect with RDP client tto the VM
After installation is complete, you will be able to login in RDP to GNOME desktop.
Connect with RDP client (i.e., from windows host) to the VM:

[![1]][1]

GNOME desktop:
 
[![2]][2]

GNOME appearance:

[![3]][3]

## <a name="Bash script"></a>5. Bash script
In the bash script, the following variable is exported: 
```console
export DEBIAN_FRONTEND=noninteractive
```

**DEBIAN_FRONTEND** is an apt-get variable can be taken different settings.  **noninteractive** is a mode when you need zero interaction while installing or upgrading the system via apt. It accepts the default answer for all questions. The option installs the package totally silent and it is a good frontend for automatic installation by shell scripts, cloud-init.


Using the folder **/etc/apt/sources.list.d/** you can easily add new repositories without the need to edit the central **/etc/apt/sources.list** repository list. The source list of repository for visual studio code, Microsoft edge and chrome are stored in the folder **/etc/apt/sources.list.d/**:
```bash
root@vm1:~# cat /etc/apt/sources.list.d/vscode.list 
deb [arch=amd64] https://packages.microsoft.com/repos/vscode stable main

root@vm1:~# cat /etc/apt/sources.list.d/microsoft-edge.list 
deb [arch=amd64] https://packages.microsoft.com/repos/edge/ stable main

root@vm1:~# cat /etc/apt/sources.list.d/google-chrome.list 
deb [arch=amd64] https://dl.google.com/linux/chrome/deb/ stable main
```


<br>

`Tags: Ubuntu VM, GNOME, RDP` <br>
`date: 15-09-22`

<!--Image References-->

[1]: ./media/remote-desktop1.png "connect in RDP to the VM"
[2]: ./media/gnome.png "GNOME desktop"
[3]: ./media/appearance.png "GNOME appearance"

<!--Link References-->
