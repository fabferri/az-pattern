<properties
pageTitle= 'NGINX configuration with server blocks using cloud-init'
description= "NGINX configuration with server blocks using cloud-init"
documentationcenter: github
services=""
documentationCenter="github"
authors="fabferri"
editor=""/>

<tags
   ms.service="howto-Azure-examples"
   ms.devlang="ARM template"
   ms.topic="article"
   ms.tgt_pltfrm="Azure"
   ms.workload="cloud-init"
   ms.date="17/08/2022"
   ms.review=""
   ms.author="fabferri" />

# NGINX configuration with server blocks using cloud-init
The network diagram is reported below:

[![1]][1]

The ARM template deploys an ubuntu VM and through cloud-init configures NGINX with server blocks. <br>
To access to nva1, you can use Azure Bastion.


## <a name="list of files"></a>2. Project files

| File name                 | Description                                                                       |
| ------------------------- | --------------------------------------------------------------------------------- |
| **init.json**             | define the value of input variables required for the full deployment              |
| **az.json**               | ARM template to deploy a vnet, Azure bastions, ubuntu VMs                         |
| **az.ps1**                | powershell script to run **az.json**                                              |
| **cloud-init-nva1.txt**   | cloud-init file to install NGINX and configure the server blocks                  |


To run the project, follow the steps in sequence:
1. change/modify the value of input variables in the file **init.json**
2. run the powershell script **az.json**
3. connect to nva1 through Azure Bastion and curl to check the homepage of web servers in the nva1 VM

## <a name="cloud-init"></a>3. cloud-init file to setup NGINX with server blocks
```yaml
#cloud-config
package_update: true
packages:
  - nginx
# Defer writing the file until after the package (Nginx) is
# installed and its user is created alongside
write_files:
  - encoding: text/plain
    path: /var/www/web101/html/index.html
    owner: www-data:www-data
    permissions: '0775'
    content: |
       <html>
       <head> <title>Welcome to web101!</title> </head>
       <body>
          <h1>web101 server block is working!</h1>
       </body>
       </html>
    defer: true
  - encoding: text/plain
    path: /var/www/web102/html/index.html
    owner: www-data:www-data
    permissions: '0775'
    content: |
       <html>
       <head> <title>Welcome to web102!</title> </head>
       <body>
         <h1>web102 server block is working!</h1>
       </body>
       </html>
    defer: true
  - encoding: text/plain
    path: /etc/nginx/sites-available/web101.conf  
    content: |
      server {
        listen 8081;
        listen [::]:8081;
        server_name  web101.local;
        root /var/www/web101/html;
        index index.html index.htm;
        location / {
          try_files $uri $uri/ =404;
        }
        access_log /var/log/nginx/web101/access.log;
        error_log /var/log/nginx/web101/error.log;
      }
    defer: true
  - encoding: text/plain
    path: /etc/nginx/sites-available/web102.conf  
    content: |
      server {
        listen 8082;
        listen [::]:8082;
        server_name  web102.local;
        root /var/www/web102/html;
        index index.html index.htm;
        location / {
          try_files $uri $uri/ =404;
        }
        access_log /var/log/nginx/web102/access.log;
        error_log /var/log/nginx/web102/error.log;
      }
    defer: true
runcmd:
  # Enable IP forward
  - [ sed, -i, -e, '$a\net.ipv4.ip_forward = 1', /etc/sysctl.conf ]
  # Apply kernel parameters
  - [ sysctl, -p ]
  - [ chmod, -R, 755, /var/www ]
  - [ chown, -R, www-data:www-data, /var/www/web101/html ]
  - [ chown, -R, www-data:www-data, /var/www/web102/html ]
  - [ mkdir, /var/log/nginx/web101/ ]
  - [ chown, -R, www-data:adm, /var/log/nginx/web101/ ]
  - [ mkdir, /var/log/nginx/web102/ ]
  - [ chown, -R, www-data:adm, /var/log/nginx/web102/ ]
  - [ systemctl, enable, nginx ]
  - [ systemctl, start, nginx ]
  - ln -s /etc/nginx/sites-available/web101.conf /etc/nginx/sites-enabled/
  - ln -s /etc/nginx/sites-available/web102.conf /etc/nginx/sites-enabled/
  # Replace the nginx homepage with simple html page with hostname 
  - [ sh, -c, 'echo "<style> h1 { color: blue; } </style> <h1>" > /var/www/html/index.nginx-debian.html' ]
  - [ sh, -c, "cat /etc/hostname >> /var/www/html/index.nginx-debian.html" ]
  - [ sh, -c, 'echo " </h1>" >> /var/www/html/index.nginx-debian.html' ]
  - [ systemctl, restart, nginx ]
  
```


`Tags: cloud-init, NGINX, Azure Bastion`
`date: 17-08-22`

<!--Image References-->

[1]: ./media/network-diagram.png "network diagram"
[2]: ./media/bastion.png "from Bastion connect to the VM via IP"

<!--Link References-->

