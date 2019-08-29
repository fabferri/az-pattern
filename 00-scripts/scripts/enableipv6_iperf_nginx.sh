#!/bin/bash

# file: /etc/sysconfig/network  row: NETWORKING_IPV6=yes
sed -i \
    -e '/^\(NETWORKING_IPV6=\).*/{s//\1yes/;:a;n;ba;q}' \
    -e '$aNETWORKING_IPV6=yes' /etc/sysconfig/network

# file: /etc/sysconfig/network-scripts/ifcfg-eth0  row: IPV6INIT=yes
sed -i \
    -e '/^\(IPV6INIT=\).*/{s//\1yes/;:a;n;ba;q}' \
    -e '$aIPV6INIT=yes' /etc/sysconfig/network-scripts/ifcfg-eth0

# file: /etc/sysconfig/network-scripts/ifcfg-eth0  row: DHCPV6C=yes
sed -i \
    -e '/^\(DHCPV6C=\).*/{s//\1yes/;:a;n;ba;q}' \
    -e '$aDHCPV6C=yes' /etc/sysconfig/network-scripts/ifcfg-eth0

# disable and enable the interface to get the new setup
ifdown eth0 && ifup eth0

#install iperf3
yum -y install iperf3

#install nginx
yum -y install epel-release
yum -y install nginx
systemctl enable nginx
sed -i 's/Fedora/Linux/g' /usr/share/nginx/html/index.html
systemctl start nginx

