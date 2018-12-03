#!/bin/bash

# Enable IP Forwarding in the Linux
sed -i -e '$a\net.ipv4.ip_forward = 1' /etc/sysctl.conf
systemctl restart network.service

# Install Apache for HealthProbe
yum -y install httpd
systemctl enable httpd.service
systemctl restart httpd.service