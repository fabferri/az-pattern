<properties
pageTitle= 'Azure ARM template with load balancer'
description= "Azure ARM template with load balancer"
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
   ms.date="07/02/2021"
   ms.author="fabferri" />

# Two Azure ARM templates to deploy external load balancer
Two different Azure load balancer configurations are available:

| file                  | Description                                                                | 
| --------------------- |--------------------------------------------------------------------------- | 
| **lb-inbound.json**   | ARM template to deploy a load balancer with inbound load balancer rule     |
| **lb-inbound.ps1**    | powershel script to deploy **lb-inbound.json**                             |
| **lb-outbound.json**  | ARM template to deploy a load balancer with inbound load balancer rule and outbound rule |
| **lb-outbound.ps1**   | powershel script to deploy **lb-outbound.json**                            |


## External Load balancer with inbound rule and NAT
The network diagram for the deployment of the **lb-outbound.json** is reported below:

[![1]][1]

> **[!NOTE]**
> Before spinning up the script **lb-outbound.ps1**  you should:
> * set the Azure subscription name in variable **$subscriptionName**
> * set the administrator username **$adminUsername** and password **$adminPassword**
>

A logical representation of the external load balancer setting with inbound rule is shown below:

[![2]][2]

The Azure VMs are deployed without public IPs.
To manage the Azure VM, a management session (SSH in linux and RDP in Windows) can be established through the external load balancer using a customer destination port (TCP port: 50000 for vm0, TCP port: 50001 for vm2, and so on).

[![3]][3]

|Name       |IP Version | Destination    |Target | Protocol | dest Port |
| --------- |-----------|----------------|-------|----------|---------- | 
| remoting0 | IPv4      | public IP lb   | vm0   | TCP      | 50000     |
| remoting1 | IPv4      | public IP lb   | vm1   | TCP      | 50001     |


The ARM template **lb-inbound.json** uses custom script extension to install the nginx  server on Ubuntu VMs using the command:
```
apt -y update 
apt -y install nginx 
systemctl enable nginx 
systemctl start nginx 
echo "<style> h1 { color: blue; } </style> <h1>" > /var/www/html/index.nginx-debian.html 
cat /etc/hostname >> /var/www/html/index.nginx-debian.html 
echo " </h1>" >> /var/www/html/index.nginx-debian.html
```
where **/var/www/html/index.nginx-debian.html** is the default homepage of nginx web server.

The list of command is joint in unique line:
```console
apt -y update && apt -y install nginx && systemctl enable nginx && systemctl start nginx && echo "<style> h1 { color: blue; } </style> <h1>" > /var/www/html/index.nginx-debian.html && cat /etc/hostname >> /var/www/html/index.nginx-debian.html && echo " </h1>" >> /var/www/html/index.nginx-debian.html
```

to install Apache2 you can use the commands:
```
apt -y update && apt -y install  apache2 && systemctl enable apache2 && systemctl start apache2 && echo "<style> h1 { color: blue; } </style> <h1>" > /var/www/html/index.html && cat /etc/hostname >> /var/www/html/index.html && echo " </h1>" >> /var/www/html/index.html
```

The **lb-inbound.json** support authentication to the Ubuntu VMs through password or RSA private key pairs.

**[NOTE!] Azure currently supports SSH protocol 2 (SSH-2) RSA public-private key pairs with a minimum length of 2048 bits. Other key formats such as ED25519 and ECDSA are not supported.**

The RSA keys can be created by ssh-keygen in OpenSSH utilities. The ssh-keygen is also available in git bash.
Example
```console
ssh-keygen \
    -m PEM \
    -t rsa \
    -b 4096 \
    -C "azureuser@myserver" \
    -f ~/.ssh/mykeys/myprivatekey \
    -N mypassphrase
```
**_Command explained_**

ssh-keygen = the program used to create the keys

-m PEM = format the key as PEM

-t rsa = type of key to create, in this case in the RSA format

-b 4096 = the number of bits in the key, in this case 4096

-C "azureuser@myserver" = a comment appended to the end of the public key file to easily identify it. Normally an email address is used as the comment, but use whatever works best for your infrastructure.

-f ~/.ssh/mykeys/myprivatekey = the filename of the private key file, if you choose not to use the default name. A corresponding public key file appended with .pub is generated in the same directory. The directory must exist.

-N mypassphrase = an additional passphrase used to access the private key file.

For more information see [Detailed steps: Create and manage SSH keys for authentication to a Linux VM in Azure](https://docs.microsoft.com/en-us/azure/virtual-machines/linux/create-ssh-keys-detailed)


To spin up  Windows VMs, in **lb-inbound.json** set the **"authenticationType":"password"** and **"windowsOrUbuntu": "Windows"**
the value of those variables can be assigned through the file  **lb-inbound.ps1**

## External Load balancer with inbound and outbound rules
The network diagram for the deployment of the **lb-outbound.json** is reported below:

[![4]][4]

> **[!NOTE]**
> Before spinning up the script **lb-outbound.ps1**  you should:
> * set the Azure subscription name in variable **$subscriptionName**
> * set the name of the resource group in the variable **$rgName**
> * set the administrator username **$adminUsername** and password **$adminPassword**
>

A logical representation of the external load balancer setting with inbound and outbound rule is shown below:

[![5]][5]

The VMs associated with the backend pool are deployed using custom script extension. The customer script extension for Windows is shown below:

```console
"powershell.exe Install-WindowsFeature -name Web-Server -IncludeManagementTools && powershell.exe remove-item 'C:\inetpub\wwwroot\iisstart.htm' && powershell.exe Add-Content -Path 'C:\inetpub\wwwroot\iisstart.htm' -Value $('Hello from: ' + $env:computername)"
```
After VMs boostrap, an IIS is created answering to the HTTP port 80. The homepage showns a simple homepage with VM hostname.

A logical representation of the external load balancer setting with inbound and outbound rules is shown below:

[![6]][6]

<!--Image References-->

[1]: ./media/lb-inbound-01.png "network diagram load balancer with inbound rule and NAT"
[2]: ./media/lb-inbound-02.png "network diagram load balancer with inbound rule and NAT"
[3]: ./media/lb-inbound-03.png "access to the Azure VM through the public IP of the external load balancer"
[5]: ./media/lb-outbound-01.png "network diagram load balancer with oubound rule"
[6]: ./media/lb-outbound-02.png "network diagram load balancer with oubound rule"

<!--Link References-->

