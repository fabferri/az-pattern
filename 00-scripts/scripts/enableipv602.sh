#!/bin/bash
# syntax: 
#        grep -q '^option' file && sed -i 's/^option.*/option=value/' file || echo 'option=value' >> file
#
#
# file: /etc/sysconfig/network  entry: NETWORKING_IPV6=yes
grep -q '^NETWORKING_IPV6' /etc/sysconfig/network && sed -i 's/^NETWORKING_IPV6.*/NETWORKING_IPV6=yes/' /etc/sysconfig/network || echo 'NETWORKING_IPV6=yes' >> /etc/sysconfig/network

# file: /etc/sysconfig/network-scripts/ifcfg-eth0  entry: IPV6INIT=yes
grep -q '^IPV6INIT' /etc/sysconfig/network-scripts/ifcfg-eth0 && sed -i 's/^IPV6INIT.*/IPV6INIT=yes/' /etc/sysconfig/network-scripts/ifcfg-eth0 || echo 'IPV6INIT=yes' >> /etc/sysconfig/network-scripts/ifcfg-eth0


# file: /etc/sysconfig/network-scripts/ifcfg-eth0  entry: DHCPV6C=yes
grep -q '^DHCPV6C' /etc/sysconfig/network-scripts/ifcfg-eth0 && sed -i 's/^DHCPV6C.*/IPV6INIT=yes/' /etc/sysconfig/network-scripts/ifcfg-eth0 || echo 'DHCPV6C=yes' >> /etc/sysconfig/network-scripts/ifcfg-eth0

# disable and reable the interface to get the new setup
ifdown eth0 && ifup eth0