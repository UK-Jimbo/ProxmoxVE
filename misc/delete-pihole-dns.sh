#!/bin/bash

# Variables - Set these before running the script
PIHOLE_SERVER="http://192.168.1.110//admin/api.php"
PIHOLE_API_TOKEN="ac8b5c84bae2a1c120833f3f2a45dba11b907542c0c8fac397309e609d231afd"

# Check for input arguments
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <domain> <ip_address>"
    exit 1
fi

DOMAIN="$1"
IP_ADDRESS="$2"

# Validate IP address format
if [[ ! $IP_ADDRESS =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
    echo "Error: Invalid IP address format."
    exit 1
fi

# Validate domain format
if [[ ! $DOMAIN =~ ^[a-zA-Z0-9.-]+$ ]]; then
    echo "Error: Invalid domain format."
    exit 1
fi

# Delete DNS entry to Pi-hole
POST="${PIHOLE_SERVER}/?customdns&action=delete&ip=${IP_ADDRESS}&domain=${DOMAIN}&auth=${PIHOLE_API_TOKEN}"
RESPONSE=$(curl -X POST -s -d "" "$POST")

# Check response
if [[ $RESPONSE == *"success"* ]]; then
    echo "Successfully deleted DNS entry: ${DOMAIN} -> ${IP_ADDRESS}"
else
    echo "Failed to delete DNS entry. Response: $RESPONSE"
    exit 1
fi
