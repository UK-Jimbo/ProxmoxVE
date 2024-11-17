#!/usr/bin/env bash

set_key_value() {
    if [ -z "$1" ] || [ -z "$2" ]; then
        echo "Usage: set_key_value <key> <value>"
        return 1
    fi
    local key="$1"
    local value="$2"
    response=$(curl -s -X POST -H "Content-Type: application/json" \
        -d "{\"key\": \"${key}\", \"value\": \"${value}\"}" \
        -w "%{http_code}" "${KEY_VALUE_STORE_URL}/set")
    body="${response%???}"  # Extract body (all except last 3 chars)
    status="${response: -3}"  # Extract status code (last 3 chars)

    if [ "$status" -eq 200 ]; then
        echo "$body"
    else
        echo "Error: $body"
    fi
}