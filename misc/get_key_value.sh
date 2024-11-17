#!/usr/bin/env bash

# URL of the key-value store server
KEY_VALUE_STORE_URL="http://phs.lan:8000"

if [ -z "$1" ]; then
    echo "Usage: get_key_value <key>"
    exit 1
fi
key="$1"
response=$(curl -s -w "%{http_code}" "${KEY_VALUE_STORE_URL}/get?key=${key}")
body="${response%???}"  # Extract body (all except last 3 chars)
status="${response: -3}"  # Extract status code (last 3 chars)

if [ "$status" -eq 200 ]; then
    echo "$body"
else
    echo "Error: $body"
fi
