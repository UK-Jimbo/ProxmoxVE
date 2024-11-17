#!/bin/bash

# Check if both domain name and port were provided as command-line arguments
if [ -z "$1" ] || [ -z "$2" ]; then
  echo "Usage: $0 <domain_name> <port>"
  exit 1
fi

DOMAIN=$1
PORT=$2
NGINX_CONF="/etc/nginx/sites-available/$DOMAIN"
NGINX_ENABLED="/etc/nginx/sites-enabled/$DOMAIN"
SSL_DIR="/etc/nginx/ssl"
CRT_FILE="$SSL_DIR/$DOMAIN.crt"
KEY_FILE="$SSL_DIR/$DOMAIN.key"

# Install NGINX if not already installed
if ! command -v nginx &> /dev/null; then
  echo "NGINX not found, installing..."
  sudo apt update
  sudo apt install -y nginx
fi

# Create the SSL directory if it doesn't exist
echo "Creating SSL directory if it doesn't exist..."
sudo mkdir -p $SSL_DIR
sudo chmod 700 $SSL_DIR

# Generate certificate using Step CA
echo "Generating certificate and private key for $DOMAIN..."
echo "YourProvisionerPassword" | step ca certificate --provisioner-password-file=password.txt $DOMAIN $CRT_FILE $KEY_FILE
sudo rm -f password.txt  # Clean up the password file after use

# Create the reverse proxy configuration for NGINX
echo "Creating NGINX reverse proxy configuration for $DOMAIN on port $PORT..."

cat <<EOL | sudo tee $NGINX_CONF
server {
    listen 80;
    server_name $DOMAIN;

    location / {
        proxy_pass http://127.0.0.1:$PORT; # Proxy to the specified port
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
    }
}

server {
    listen 443 ssl;
    server_name $DOMAIN;

    ssl_certificate $CRT_FILE;
    ssl_certificate_key $KEY_FILE;

    location / {
        proxy_pass http://127.0.0.1:$PORT;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
    }
}
EOL

# Enable the new site by creating a symbolic link to sites-enabled
echo "Enabling NGINX configuration for $DOMAIN..."
sudo ln -s $NGINX_CONF $NGINX_ENABLED

# Test NGINX configuration for errors
echo "Testing NGINX configuration..."
sudo nginx -t

if [ $? -eq 0 ]; then
  # Reload NGINX to apply the new configuration
  echo "Reloading NGINX..."
  sudo systemctl reload nginx
  echo "Reverse proxy for $DOMAIN on port $PORT with SSL has been set up and NGINX reloaded."
else
  echo "NGINX configuration test failed. Please check the configuration file."
  exit 1
fi
