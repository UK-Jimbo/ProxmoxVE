#!/usr/bin/env bash


# This a testing file to test the functionality of https

source install.func

VERBOSE="no"

# URL of the key-value store server
KEY_VALUE_STORE_URL="http://phs.lan:8000"

check_host_response() {
    local host="$1"
    local port="$2"
    local timeout=2  # Timeout in seconds for the checks

    if [ -z "$host" ]; then
        echo "Error: Host must be specified."
        return 2
    fi

    if [ -z "$port" ]; then
        # If no port is provided, use ping to check host availability
        if ping -c 1 -W "$timeout" "$host" > /dev/null 2>&1; then
            return 0
        else
            return 1
        fi
    else
        # If a port is provided, check for a listening service using nc
        if nc -z -w "$timeout" "$host" "$port" > /dev/null 2>&1; then
            return 0
        else
            return 1
        fi
    fi
}

function get_key_value() {
    if [ -z "$1" ]; then
        echo "Usage: get_key_value <key>"
        exit 1
    fi
    local key="$1"
    response=$(curl -s -w "%{http_code}" "${KEY_VALUE_STORE_URL}/get?key=${key}")
    body="${response%???}"  # Extract body (all except last 3 chars)
    status="${response: -3}"  # Extract status code (last 3 chars)

    if [ "$status" -eq 200 ]; then
        echo "$body"
    else
        echo "Error: $body"
    fi
}

function add_pihole_dns() {

    # Check for input arguments
    if [ "$#" -ne 2 ]; then
        msg_error "Usage: $0 <domain> <ip_address>"
        exit 1
    fi

    local DOMAIN="$1"
    local IP_ADDRESS="$2"

    # Validate IP address format
    if [[ ! $IP_ADDRESS =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
        msg_error "Error: Invalid IP address format."
        exit 1
    fi

    # Validate domain format
    if [[ ! $DOMAIN =~ ^[a-zA-Z0-9.-]+$ ]]; then
        msg_error "Error: Invalid domain format."
        exit 1
    fi

    # Add DNS entry to Pi-hole
    POST="${PIHOLE_SERVER}/?customdns&action=add&ip=${IP_ADDRESS}&domain=${DOMAIN}&auth=${PIHOLE_API_TOKEN}"
    RESPONSE=$(curl -X POST -s -d "" "$POST")

    # Check response
    if ! [[ $RESPONSE == *"success"* ]]; then
        msg_error "Failed to add DNS entry."
        exit 1
    fi
}

color
verb_ip6

msg_info "Checking phs"
if ! check_host_response "phs.lan" "8000"; then
    msg_error "phs.lan is unreachable. Exiting."
    exit 1
fi
msg_ok "Checked phs"

msg_info "Checking Step-CA"
STEPCA_URL=$(get_key_value "STEPCA_URL")
if ! check_host_response "$STEPCA_URL"; then
    msg_error "Step-CA is unreachable. Exiting."
    exit 1
fi
msg_ok "Checked Step-CA"

msg_info "Checking Pi-hole"
PIHOLE_URL=$(get_key_value "PIHOLE_URL")
if ! check_host_response "$PIHOLE_URL"; then
    msg_error "Pi-hole is unreachable. Exiting."
    exit 1
fi
msg_ok "Checked Pi-hole"

msg_info "Checking Pi-hole API Key"
PIHOLE_SERVER="$PIHOLE_URL/admin/api.php"
PIHOLE_API_TOKEN=$(get_key_value "PIHOLE_API_TOKEN")
STATUS_URL="${PIHOLE_SERVER}?status&auth=${PIHOLE_API_TOKEN}"
RESPONSE=$(curl -s "$STATUS_URL")

if ! [[ "$RESPONSE" == *"enabled"* ]]; then
    msg_error "Pi-hole API Key invalid"
    exit 1
fi
msg_ok "Checked Pi-hole API Key"

IP_ADDRESS=$(hostname -I | awk '{print $1}')

# Commented out as worked first time, dont want to run twice
msg_info "Adding Pi-hole DNS entry"
#add_pihole_dns "$(hostname -f)" "$IP_ADDRESS"
msg_ok "Added Pi-hole DNS entry"

# Commented out as worked first time, dont want to run twice
msg_info "Installing Step-CA"
#wget https://dl.smallstep.com/cli/docs-cli-install/latest/step-cli_amd64.deb
#sudo dpkg -i step-cli_amd64.deb
msg_ok "Installed Step-CA"

# Commented out as worked first time, dont want to run twice
msg_info "Configuring Step-CA"
# # Consider testing port 9000 above ?
# STEPCA_FINGERPRINT=$(get_key_value "STEPCA_FINGERPRINT")
# STEPCA_PROVISIONER_PASSWORD=$(get_key_value "STEPCA_PROVISIONER_PASSWORD")

# step ca bootstrap --ca-url https://$STEPCA_URL:9000 --fingerprint "$STEPCA_FINGERPRINT" --install

# echo "$STEPCA_PROVISIONER_PASSWORD" > password.txt
# step ca certificate --provisioner-password-file=password.txt "$(hostname -f)" "$(hostname -f).crt" "$(hostname -f).key"
# rm password.txt
msg_ok "Configured Step-CA"

DOMAIN=$(hostname -f)
PORT=8088
NGINX_CONF="/etc/nginx/sites-available/$DOMAIN"
NGINX_ENABLED="/etc/nginx/sites-enabled/$DOMAIN"
SSL_DIR="/etc/nginx/ssl"
CRT_FILE="$SSL_DIR/$DOMAIN.crt"
KEY_FILE="$SSL_DIR/$DOMAIN.key"

# Install NGINX if not already installed
if ! command -v nginx &> /dev/null; then
    msg_info "Installing NGINX"
    echo "NGINX not found, installing..."
    sudo apt update
    sudo apt install -y nginx
    msg_ok "Installed NGINX"
fi

# Create the SSL directory if it doesn't exist
msg_info "Copying Certificates"
sudo mkdir -p $SSL_DIR
sudo chmod 700 $SSL_DIR

sudo cp $DOMAIN.crt $SSL_DIR/$DOMAIN.crt
sudo cp $DOMAIN.key $SSL_DIR/$DOMAIN.key
msg_ok "Copied Certificates"

# Create the reverse proxy configuration for NGINX
msg_info "Creating NGINX reverse proxy for $DOMAIN on port $PORT"

cat <<EOL | sudo tee $NGINX_CONF
server {
    listen 80;
    server_name $DOMAIN;

    # Redirect all HTTP traffic to HTTPS
    return 301 https://\$host\$request_uri;
}

server {
    listen 443 ssl;
    server_name $DOMAIN;

    ssl_certificate $CRT_FILE;
    ssl_certificate_key $KEY_FILE;

    location / {
        proxy_pass http://127.0.0.1:$PORT; # Proxy to the specified port
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
    }
}
EOL

# Enable the new site by creating a symbolic link to sites-enabled
#echo "Enabling NGINX configuration for $DOMAIN..."
sudo ln -s $NGINX_CONF $NGINX_ENABLED
msg_ok "Created NGINX Reverse Proxy"

# Test NGINX configuration for errors
msg_info "Testing NGINX configuation"
#echo "Testing NGINX configuration..."
sudo nginx -t

if [ $? -eq 0 ]; then
    # Reload NGINX to apply the new configuration
    msg_info "Reloading NGINX..."
    sudo systemctl reload nginx
    #  echo "Reverse proxy for $DOMAIN on port $PORT with SSL has been set up and NGINX reloaded."
    msg_ok "Reloaded NGINX"
else
    msg_error "NGINX configuration test failed."
    exit 1
fi

# Install Root on iMac
# step ca bootstrap --ca-url https://step-ca.lan:9000 --fingerprint 3c71803de1271802174c5975ee1d05f499af3972689d832ecb57c19c42952a6e --install

# TODO
# - [x] Check phs.lan pings
# - [x] Check stepca pings
# - [x] Get pihole api key
# - [x] Check pihole api key works
# - [x] Add DNS functions
# - [x] Add kv functions
# - [x] Add DNS to pihole
# - [x] Get stepca fingerprint, provisioner password and password
# - [x] Install stepca
# - [x] Configure stepca
# - [x] Install NGINX
# - [x] Configure NGINX
# - [x] Install Root Certificate on iMac