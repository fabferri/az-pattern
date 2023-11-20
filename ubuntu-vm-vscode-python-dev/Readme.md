<properties
pageTitle= 'Ubuntu VM with GNOME desktop, Python and Visual Studio Code'
description= "Ubuntu VM with Gnome desktop and Python installed through customer script extension"
services="GNOME desktop, Visual Studio Code, Python"
documentationCenter="https://github.com/fabferri/"
authors="fabferri"
editor=""/>

<tags
   ms.service="configuration-Example-Azure"
   ms.devlang="ARM template"
   ms.topic="article"
   ms.tgt_pltfrm="Azure"
   ms.workload="Ubuntu VM with GNOME desktop"
   ms.date="20/11/2023"
   ms.author="fabferri" />

# Ubuntu VM with GNOME desktop, Python and Visual Studio Code
The ARM template deploys an Ubuntu server 22.04 and it uses custom script extension to install GNOME desktop and Remote desktop support via **xrdp**. 
The custom script extension installs the following components:
- ubuntu-desktop-minimal (minimal is a subset of all full Ubuntu desktop). GNOME is the default desktop environment for Ubuntu 20.04 Focal Fossa Linux.
- xrdp: it is a Remote Desktop Protocol (RDP) Server
- Python (if not already installed in Ubuntu image from Azure marketplace)
- Python venv (virtual environment) package
- Visual Studio Code
- Chrome web browser
- Visual Studio Code Python extension
- Visual Studio Code Jupyter notebook extension


**Note:**<br>
When you connect to the VM via RDP, the desktop looks different from local login. The GNOME dock isn't present on the home screen and in GNOME desktop setting is not present the **Appearance** option. <br>
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
| file                    | Description                                                                   | 
| ----------------------- |------------------------------------------------------------------------------ |
| **init.json**           | file with value of variables to set Azure subscription name, Resource Group, VM Administrator credential, URL of bash script to run the VM custom script extension |
| **01-vnet-vms.json**    | ARM template to deploy an ubuntu 22.04 VM and run the custom script extension |
| **01-vnet-vms.ps1**     | powershell script to deploy **01-vnet-vms.json**                              |
| **dev-python.sh**       | bash script to install Gnome, Python, VS Code with Python extension, Jupyter notebook extension, Chrome web browser |



**NOTE:** <br>
- Before running the **01-vnet-vms.ps1** customize the value of variables in the **init.json**:
- The deployment has been tested successful with **Standard_B2als_v2** (2 vcpus, 4 GiB memory) but a larget VM SKU would be better


## <a name="Custom script extension"></a>2. Check the correct installation
When the deployment is completed, it is good practice verifying the custom script extension correct installation. <br>
Custom script extension logs are stored in:
```
root@vm1:~# ll /var/lib/waagent/custom-script/download/0/
root@vm1:~# cat /var/lib/waagent/custom-script/download/0/stderr
root@vm1:~# cat /var/lib/waagent/custom-script/download/0/stdout
root@vm1:~# cat /var/lib/waagent/custom-script/download/0/dev-python.sh
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


## <a name="Check the last reboot time"></a>3. Check the last reboot time
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

## <a name="Check the last reboot time"></a>4. Connect with RDP client to the VM
The NSG applied to the NIC of the VM allows access through SSH and RDP. 
After installation is complete, you will be able to login in RDP to GNOME desktop.
Connect with RDP client (i.e., from windows host) to the VM; GNOME appearance is shonw below:

[![1]][1]

## <a name="Bash script"></a>5. Bash script
In the bash script, the following variable is exported: 
```console
export DEBIAN_FRONTEND=noninteractive
```

**DEBIAN_FRONTEND** is an apt-get variable can be taken different settings.  **noninteractive** is a mode when you need zero interaction while installing or upgrading the system via apt. It accepts the default answer for all questions. The option installs the package totally silent, and it is a good frontend for automatic installation by shell scripts, cloud-init.

Using the folder **/etc/apt/sources.list.d/** you can easily add new repositories without the need to edit the central **/etc/apt/sources.list** repository list. The source list of repositories for visual studio code, Microsoft edge and chrome are stored in the folder **/etc/apt/sources.list.d/**:
```bash
root@vm1:~# cat /etc/apt/sources.list.d/vscode.list 
deb [arch=amd64] https://packages.microsoft.com/repos/vscode stable main

root@vm1:~# cat /etc/apt/sources.list.d/microsoft-edge.list 
deb [arch=amd64] https://packages.microsoft.com/repos/edge/ stable main

root@vm1:~# cat /etc/apt/sources.list.d/google-chrome.list 
deb [arch=amd64] https://dl.google.com/linux/chrome/deb/ stable main
```

Installation of Visual Studio extensions are executed by customer script running with the following commands:
```console
# install Visual Studio Code Extensions for Python:
code --install-extension  ms-python.python

# install Visual Studio Code Extension for Jupyter notebook
code --install-extension  ms-toolsai.jupyter
```

you can check the list of VS Code extensions by command:
```console
code --list-extensions
```
or inside the Visual Studio Code:

[![2]][2]

## <a name="Check Python"></a>6. Create a Python virtual environment and run a python example 
Let's create a directory called test1:
```bash
mkdir test1
cd test1
```

Create a virtual environment called test_env:
```bash
python3 -m venv test_env
```

The generated files configure the virtual environment to work separately from our host files. <br>
Activation of the environment is as follows:
```bash
source ./test_env/bin/activate
```

If you should need to disable the virtual environment, run the command **deactivate**:
```bash
./test_env/bin/deactivate
```

To test the virtual environment:
```bash
vim hello.py
```

Inside the file write:
```console
msg="first test"
print(msg)
```

Run the python file:
```bash
python3 hello.py
```

To upgrade the pip package global:
```
 python3 -m pip install --upgrade pip
```

To upgrade pip only in virtual environment, go into the test_env folder then run:
```
./test_env/bin/python3 -m pip install --upgrade pip
```

## <a name=" matplotlib"></a>7. matplotlib 
To install the matplotlib:
```
python3 -m pip install -U matplotlib
```

To plot with **matplotlib** looks like a **tkinter** package is required. The **tkinter** package ("Tk interface") is the standard Python interface to the Tcl/Tk GUI toolkit. Both Tk and tkinter are available on most Unix platforms, including macOS, as well as on Windows systems. <br>
To install **tk** package:
```bash
sudo apt-get -y install python3-tk
```
The package works because fine because you get a GUI backend, in this case the **TkAgg**.

Simple python example with matplotlib:
```python
import matplotlib.pyplot as plt
import numpy as np

ax = plt.figure().add_subplot(projection='3d')

# Prepare arrays x, y, z
theta = np.linspace(-4 * np.pi, 4 * np.pi, 100)
z = np.linspace(0, 2, 100)
r = z**2 + np.log10(z+2.5)
x = r * np.sin(theta)
y = r * np.cos(theta)

ax.plot(x, y, z, label='parametric curve')
ax.legend()

plt.show()
```


`Tags: Ubuntu VM, GNOME, RDP, Python, Visual Studio Code` <br>
`date: 20-11-23`

<!--Image References-->

[1]: ./media/01.png "connect in RDP to the VM and GNOME appearance"
[2]: ./media/02.png "Visual Studio extensions automatically installed by VM script extension"

<!--Link References-->
