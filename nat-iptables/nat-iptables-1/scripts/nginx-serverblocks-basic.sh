#!/bin/bash
#
# Nginx - new server blocks
#
# Create folders:
mkdir -p /var/www/web101/html
mkdir -p /var/www/web102/html

# Assign ownership
chown -R $USER:$USER /var/www/web101/html
chown -R $USER:$USER /var/www/web102/html

# Grant reading permission to all the files inside the /var/www directory
sudo chmod -R 755 /var/www

# Reassign ownership of the web directories to NGINX user (www-data):
chown -R www-data:www-data /var/www/web101/html
chown -R www-data:www-data /var/www/web102/html

# Create the content you want to display on the websites hosted on Nginx server 
cat <<EOF > /var/www/web101/html/index.html
<html>
    <head> <title>Welcome to web101!</title> </head>
    <body>
        <h1>web101 server block is working!</h1>
    </body>
</html>
EOF

cat <<EOF > /var/www/web102/html/index.html
<html>
    <head> <title>Welcome to web102!</title> </head>
    <body>
        <h1>web102 server block is working!</h1>
    </body>
</html>
EOF

# Inside the  file /etc/nginx/nginx.conf check the two lines:
#    include /etc/nginx/conf.d/*.conf;
#    include /etc/nginx/sites-enabled/*;
# The line include /etc/nginx/sites-enabled/*.conf instructs NGINX to check the sites-enabled directory.


# Create the server blocks for the site web101
cat <<EOF > /etc/nginx/sites-available/web101.conf
server {
        listen 8081;
        listen [::]:8081;
        server_name  web101.local;

        root /var/www/web101/html;
        index index.html index.htm;
        location / {
                try_files \$uri \$uri/ =404;
        }
        access_log /var/log/nginx/web101/access.log;
	    error_log /var/log/nginx/web101/error.log;
}
EOF

# Create the server blocks for the site web102
cat <<EOF > /etc/nginx/sites-available/web102.conf
server {
        listen 8082;
        listen [::]:8082;
        server_name  web102.local;

        root /var/www/web102/html;
        index index.html index.htm;
        location / {
                try_files \$uri \$uri/ =404;
        }
        access_log /var/log/nginx/web102/access.log;
	    error_log /var/log/nginx/web102/error.log;
}
EOF

# Enable the new server block files, by creating symbolic links:
ln -s /etc/nginx/sites-available/web101.conf /etc/nginx/sites-enabled/
ln -s /etc/nginx/sites-available/web102.conf /etc/nginx/sites-enabled/

# Create the folders for the logs:
mkdir -p /var/log/nginx/web101/
mkdir -p /var/log/nginx/web102/
chown -R www-data:adm /var/log/nginx/web101/
chown -R www-data:adm /var/log/nginx/web102/

# Check errors:
sudo nginx -t

# Restart NGINX:
sudo systemctl restart nginx