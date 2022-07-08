<properties
pageTitle= 'Load balancing HTTP traffic by NGINX'
description= "Load balancing HTTP traffic by NGINX"
documentationcenter: na
services=""
documentationCenter="github"
authors="fabferri"
manager=""
editor=""/>

<tags
   ms.service="howto-Azure-examples"
   ms.devlang="na"
   ms.topic="article"
   ms.tgt_pltfrm="na"
   ms.workload="load balancing, NVA"
   ms.date="18/07/2022"
   ms.review=""
   ms.author="fabferri" />

# Load balancing HTTP traffic by NGINX
The article describes a scenario with NGINX configured as load balancer, with 4 backend web servers: two web servers in the same vnet and two web server configured in backup, in a vnet in peering

[![1]][1]



## <a name="list of files"></a>1. Project files

| File name                 | Description                                                                             |
| ------------------------- | --------------------------------------------------------------------------------------- |
| **init.json**             | define the value of input variables required for the full deployment                    |
| **nginx.json**            | ARM template to deploy vnets, vnet peering, VMs, NGINX in the VMs with custom web page  |
| **nginx.ps1**             | powershell script to run **nginx.json**                                                 |


To run the project, follow the steps in sequence:
1. change/modify the value of input variables in the file **init.json**
2. run the powershell script **nginx.ps1**; at the end of execution the full environment is generated


The meaning of input variables in **init.json** are shown below:
```json
{
    "subscriptionName": "NAME_OF_AZURE_SUBSCRIPTION",
    "ResourceGroupName": "NAME_OF_RESOURCE_GROUP",
    "locationhub1": "AZURE_LOCATION_hub1_VNET",
    "locationhub2": "AZURE_LOCATION_hub2_VNET",
    "adminUsername": "ADMINISTRATOR_USERNAME",
    "authenticationType": "password",
    "adminPasswordOrKey": "ADMINISTRATOR_PASSWORD",
    "mngIP": "PUBLIC_IP_ADDRESS_TO_FILTER_SSH_ACCESS_TO_VMS - it can be empty string, if you do not want to filter access!"
}
```

The ARM template uses the customer script extension to install ngix and setup a simple homepage.

## <a name="nva"></a>2. NGINX load balancer setup
by custom script extension the ARM template installs NGINX on all the VMs. <br>
Below the steps to configure the NGINX as load balancer HTTP traffic across application server groups.
<br>

By default, NGINX web server listens on port 80. You can check it by running the following command:
```bash
ss -antpl
```
you should see the NGINX port 80:
```console
State       Recv-Q      Send-Q           Local Address:Port           Peer Address:Port     Process                                                      
LISTEN      0           511                    0.0.0.0:80                  0.0.0.0:*         users:(("nginx",pid=5209,fd=6),("nginx",pid=5208,fd=6))     
LISTEN      0           4096             127.0.0.53%lo:53                  0.0.0.0:*         users:(("systemd-resolve",pid=534,fd=14))                   
LISTEN      0           128                    0.0.0.0:22                  0.0.0.0:*         users:(("sshd",pid=1573,fd=3))                              
LISTEN      0           511                       [::]:80                     [::]:*         users:(("nginx",pid=5209,fd=7),("nginx",pid=5208,fd=7))     
LISTEN      0           128                       [::]:22                     [::]:*         users:(("sshd",pid=1573,fd=4))
```

[![2]][2]

To setup NGINX as a load balancer, follow these steps:
1. Open the NGINX configuration file with elevated rights
2. Define an upstream element and list each node in your backend cluster
3. Map a URI to the upstream cluster with a **proxy_pass** location setting
4. Restart the NGINX server to incorporate the config changes
5. Verify the NGINX load balancer setup was configured successfully


### <a name="NGINX"></a>2.1 NGINX config step1 - edit the configuration file /etc/nginx/sites-available
NGINX uses a text‑based configuration file written in a particular format. By default the file is named **nginx.conf** placed in the **/etc/nginx** folder.
To configure Nginx as load balancer, you will need to work on NGINX virtual host (AKA server Blocks) configuration files. Virtual host config files are typically located in the **/etc/nginx/sites-available** folder.
You may also notice that your server has two folders 
- **/etc/nginx/sites-available**, which is Virtual host config files are typically located
- **/etc/nginx/sites-enabled**, which is where file shortcuts (symbolic links) are placed. You can use the sites-enabled folder to easily enable or disable a virtual host by creating or removing symbolic links. By default, the logical link point to the file **/etc/nginx/sites-available/default**:
```bash
root@nginx:/etc/nginx/sites-enabled# ll
total 8
drwxr-xr-x 2 root root 4096 Jul  7 13:32 ./
drwxr-xr-x 8 root root 4096 Jul  7 15:11 ../
lrwxrwxrwx 1 root root   34 Jul  7 13:32 default -> /etc/nginx/sites-available/default
```

### <a name="NGINX"></a>2.2 NGINX config step2 - define a group of upstream servers
The **ngx_http_upstream_module** module is used to define groups of servers that can be referenced by the **proxy_pass** directives. <br>
Edit the file **/etc/nginx/sites-available/default** and add the following content:

```nginx
upstream backend {
        server 10.1.0.50 weight=3 max_fails=3 fail_timeout=6s;
        server 10.1.0.51 weight=3 max_fails=3 fail_timeout=6s;
        server 10.2.0.50 backup max_fails=3 fail_timeout=6s;
        server 10.2.0.51 backup max_fails=3 fail_timeout=6s;
}
```
In the above example, if NGINX fails to send a request to a server or does not receive a response from it 3 times in 6 seconds, it marks the server as unavailable for 6 seconds.
Let's discuss 
### Weight
By default, NGINX distributes requests among the servers in the group according to their weights using the Round Robin method. The weight parameter to the server directive sets the weight of a server; the default is 1.

### backup
backup: marks the server as a backup server. Connections to the backup server will be passed when the primary servers are unavailable. 

### health probe
For passive health checks, NGINX open source monitor transactions as they happen, and try to resume failed connections. If the transaction still cannot be resumed, NGINX open source marks the server as unavailable and temporarily stop sending requests to it until it is marked active again. The conditions under which an upstream server is marked unavailable are defined for each upstream server with parameters to the server directive in the upstream block:
* **fail_timeout** – sets the time during which a number of failed attempts must happen for the server to be marked unavailable, and also the time for which the server is marked unavailable (default is 10 seconds).
* **max_fails** – sets the number of failed attempts that must occur during the **fail_timeout** period for the server to be marked unavailable (default is 1 attempt).

### <a name="NGINX"></a>2.3 NGINX config step3 - reverse proxy
NGINX load balancer has to act also as a reverse proxy. When NGINX proxies a request, it sends the request to a specified proxied server, fetches the response, and sends it back to the client. <br>
A location element with a NGINX **proxy_pass** entry must also be configured in the default configuration file:
```nginx
location / {
            proxy_pass http://backend;
}
```
All requests to NGINX that include the / URL will be forwarded to one of the two application servers listed in the upstream element named backend.


The full NGINX configuration as load balancer is shown below:

```nginx
upstream backend {
        server 10.1.0.50 weight=3 max_fails=3 fail_timeout=6s;
        server 10.1.0.51 weight=3 max_fails=3 fail_timeout=6s;
        server 10.2.0.50 backup max_fails=3 fail_timeout=6s;
        server 10.2.0.51 backup max_fails=3 fail_timeout=6s;
}

server {
        listen 80 default_server;
        listen [::]:80 default_server;

        root /var/www/html;

        # Add index.php to the list if you are using PHP
        index index.html index.htm index.nginx-debian.html;

        server_name _;

        location / {
                proxy_redirect      off;
                proxy_set_header    X-Real-IP $remote_addr;
                proxy_set_header    X-Forwarded-For $proxy_add_x_forwarded_for;
                proxy_set_header    Host $http_host;
                proxy_pass http://backend;
       }
}
```

### <a name="NGINX"></a>2.4 NGINX config step4 - restart NGINX
```bash
sudo systemctl restart nginx
```

### <a name="NGINX"></a>2.4 NGINX config step5 - check the configuration/behaviour
- Login in the client VM and query by curl the NGINX configurated as load balancer; the traffic is balanced between web12 and web21:
```bash
root@client1:~# curl http://10.1.0.10/
<style> h1 { color: blue; } </style> <h1>
web11
 </h1>
root@client1:~# curl http://10.1.0.10/
<style> h1 { color: blue; } </style> <h1>
web12
 </h1>
```
- stop the NGINX in web11; the HTTP traffic from the client is sent only to the web12 
- stop the NGINX in web12; the HTTP traffic from the client is sent in balancing to the backup servers web21 and web22
- stop the NGINX in web21; the HTTP traffic from the client is sent only to the last active server web22
- start the NGIX in web11; all the HTTP traffic from the client is sent only to the web11
- start the NGIX in web21; all the HTTP traffic from the client is sent in balancing to web12 and web12

## <a name="NGINX"></a>3. Caveats
The configuration is not resilent to a failure of NGINX load balancer. A failure in ngix1 VM will casue a failure in the web service. 

`Tags: nginx, load balancer`
`date: 07-07-22`

<!--Image References-->

[1]: ./media/network-diagram1.png "network diagram"
[2]: ./media/network-diagram2.png "NGINX configured as load balancer"


<!--Link References-->

