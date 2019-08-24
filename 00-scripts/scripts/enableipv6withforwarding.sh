#!/bin/bash

############# enable IPv6 on the interface
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

############# enable IPv6 forwarding
#file: /etc/sysctl.conf, entry: net.ipv6.conf.all.forwarding=1
sed -i \
    -e '/^\(net.ipv6.conf.all.forwarding=\).*/{s//\11/;:a;n;ba;q}' \
    -e '$anet.ipv6.conf.all.forwarding=1' /etc/sysctl.conf

#file: /etc/sysctl.conf, entry: net.ipv6.conf.eth0.accept_ra=2
sed -i \
    -e '/^\(net.ipv6.conf.eth0.accept_ra=\).*/{s//\12/;:a;n;ba;q}' \
    -e '$anet.ipv6.conf.eth0.accept_ra=2' /etc/sysctl.conf

systemctl restart network.service