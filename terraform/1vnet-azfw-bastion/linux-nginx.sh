#!/bin/bash
sleep 1m
sudo apt update
sudo apt-get -y install nginx 
sudo systemctl enable nginx 
sudo systemctl start nginx 
echo "<style> h1 { color: blue; } </style> <h1>" > /var/www/html/index.nginx-debian.html 
cat /etc/hostname >> /var/www/html/index.nginx-debian.html 
echo "</h1>" >> /var/www/html/index.nginx-debian.html
