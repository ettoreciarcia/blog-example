#!/bin/bash

# Set default values
name=$RANDOM
url='http://localhost:9093/api/v2/alerts'
summary='Testing summary!'
instance="$name.example.net"
default_severity='warning'

# Function to send alert
send_alert() {
    local status=$1
    local custom_severity=$2
    local current_severity=${custom_severity:-$default_severity}

    curl -XPOST -H "Content-Type: application/json" $url -d "[
        {
            \"status\": \"$status\",
            \"labels\": {
                \"alertname\": \"$name\",
                \"service\": \"my-service\",
                \"severity\":\"$current_severity\",
                \"instance\": \"$instance\"
            },
            \"annotations\": {
                \"summary\": \"$summary\"
            },
            \"generatorURL\": \"http://prometheus.local/<generating_expression>\"
        }
    ]"
    echo ""
}

# Main script
echo "Firing up alert $name"
send_alert "firing" "$1"

read -p "Press enter to resolve alert"

echo "Sending resolve"
send_alert "resolved" "$1"