<properties
pageTitle= 'Azure ubuntu VM deployed with customer script extension through Azure Python SDK'
description= "Azure ubuntu VM deployed with customer script extension through Azure Python SDK"
services="Python Azure SDK"
documentationCenter="https://github.com/fabferri"
authors="fabferri"
editor="fabferri"/>

<tags
   ms.service="howto-Azure-examples"
   ms.devlang="na"
   ms.topic="article"
   ms.tgt_pltfrm="Azure"
   ms.workload="Azure Python SDK"
   ms.date="17/09/2025"
   ms.review=""
   ms.author="fabferri" />

# Azure ubuntu VM deployed with customer script extension through Azure Python SDK

This article demonstrates how to deploy a virtual network (VNet) and an Ubuntu virtual machine (VM) using the Azure Python SDK. As part of the deployment, a Custom Script Extension is used to install NGINX and configure a custom homepage.
The network architecture is illustrated below:

[![1]][1]

The custom script extension is defined in Python using a JSON block that executes the following shell commands:

```bash
!/bin/bash
sudo apt-get update -y
sudo apt-get install nginx -y
sudo systemctl enable nginx
sudo systemctl start nginx
echo '<h1>Deployed via Azure Custom Script Extension</h1>' | sudo tee /var/www/html/index.nginx-debian.html
```

These commands are passed as a single string in the JSON payload, with each command separated by **\n**.


### <a name="file list"></a>1. File list

| file                   | description                                               |
| ---------------------- | --------------------------------------------------------- |
| **.env***              | it contains the values of Azure Subscription Id and Administrator Username of the VM  |
| **requirements.txt**   | list of python libraries required to run the code |
| **vm.py**              | python code to create azure vnet, Azure VM, custom script extension to deploy nginx    |

### <a name="file list"></a>2. Deployment Steps

Follow these steps to deploy the Azure Ubuntu VM with a custom script extension using the Azure Python SDK:

1. **Set up a Python virtual environment**
Use Visual Studio Code or your preferred IDE to create a virtual environment. This will generate a **.venv** folder in your project directory. (See the Annex for detailed instructions.)

2. **Configure environment variables**
Create a **.env** file and define the following variables:

```console
AZURE_SUBSCRIPTION_ID="REPLACE_HERE_WIT_YOUR_AZURE_SUBSCRIPTION_ID"
ADMINISTRATOR_USERNAME="REPLACE_HERE_WITH_YOUR_ADMINISTRATOR_USER"
```

3. **Install required Python packages**
Run the following command to install dependencies listed in **requirements.txt**:

`pip install -r requirements.txt`

4. **Run the deployment script**
Execute the **vm.py** script. It reads the administrator username from the **.env** file and uses it to configure the VM. During execution, the script also generates RSA key pairs:

<br>

Private key: **id_rsa.pem** <br>
Public key: **id_rsa.pub** <br>

These keys are saved locally and used for SSH access to the deployed VM.

> [!NOTE]
>
> Open the Terminal in Visual Studio Code; in **venv** execute the python code by: **(.venv) C:\localpath_to_the_code> py .\vm.py**
>

<br>

At deployment completed, connected to the VM:

```
ssh ADMINISTRATOR_USERNAME@PUBLIC_IP_VM -i .\id_rsa.pem
```


### <a name="python .vnenv"></a>2. Annex: Python virtual environment in Visual Studio Code

Selection in Command Palette of **Python: Create Environment**:

[![2]][2]

<br>

Selection of Venv for the current workspace:

[![3]][3]

<br>

Selection of Python interpreter:

[![4]][4]

<br>

Skip the requirements.txt if you **pip install -r requirements.txt** after creation of Venv:

[![5]][5]

<br>

Screenshot showing the on-going creation of venv:

[![6]][6]

<br>

Visual Studio Code creates automatically in local folder the following folders and file structure:

[![7]][7]

`Tags: Azure Python SDK` <br>
`date: 17-09-2025` <br>

<!--Image References-->

[1]: ./media/network-diagram.png "network diagram"
[2]: ./media/venv01.png "virtual environment in Visual Studio Code"
[3]: ./media/venv02.png "virtual environment in Visual Studio Code"
[4]: ./media/venv03.png "virtual environment in Visual Studio Code"
[5]: ./media/venv04.png "virtual environment in Visual Studio Code"
[6]: ./media/venv05.png "virtual environment in Visual Studio Code"
[7]: ./media/venv06.png "virtual environment in Visual Studio Code"

<!--Link References-->
