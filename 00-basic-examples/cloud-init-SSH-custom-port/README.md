<properties
pageTitle= 'Custom ports for SSH and NGIX via cloud-init'
description= "Custom port for SSH and NGIX via cloud-init"
documentationcenter: na
services="cloud-init"
documentationCenter="na"
authors="fabferri"
manager=""
editor="fabferri"/>

<tags
   ms.service="configuration-Example-Azure"
   ms.devlang="na"
   ms.topic="article"
   ms.tgt_pltfrm="Azure"
   ms.workload="na"
   ms.date="26/05/2022"
   ms.author="fabferri" />

# Custom ports for SSH and NGIX via cloud-init
The example uses cloud-init to customize the port for SSH and for NGINX. The network diagram is shown below:  

[![1]][1]

The cloud-init file has the following structure:
```console
#cloud-config
package_upgrade: true
packages:
  - nginx
runcmd:
  - sed -i "s/#Port 22/Port 2223/" /etc/ssh/sshd_config
  - sed -i '/^#/! s/80/8081/g' /etc/nginx/sites-enabled/default
  - service ssh restart
  - service nginx restart

```
* the SSH is customized on the port 2223
* the default page of nginx  is set to the port 8081

The NSGs associated with NICs have security rules to allow incoming connections on those two ports. 

<!--Image References-->

[1]: ./media/network-diagram.png "network diagram" 

<!--Link References-->

