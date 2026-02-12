#!/bin/bash
CUSTOM_HTML="$1"
CUSTOM_AUTH_DATA="$2"

# Update packages
apt-get update -y
apt-get install nginx -y

# Deploy HTML
echo "$CUSTOM_HTML" > /var/www/html/index.html

# Optional Auth
echo "$CUSTOM_AUTH_DATA" > /etc/nginx/auth.txt

# Start NGINX
systemctl enable nginx
systemctl start nginx
