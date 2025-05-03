#!/bin/bash

check_port_usage() {
    local port=$1
    if ss -tuln | grep -q ":$port"; then
        echo "Port $port is already in use. Exiting."
        exit 1
    fi
}

open_port_ufw() {
    local port=$1
    echo "Opening port $port in UFW firewall..."
    sudo ufw allow $port/tcp
    sudo ufw reload
}

open_port_iptables() {
    local port=$1
    echo "Opening port $port in iptables..."
    sudo iptables -A INPUT -p tcp --dport $port -j ACCEPT
    sudo iptables-save
}

add_inbound_rule_xui() {
    local port=$1
    echo "Adding inbound rule for port $port in X-UI..."
    
    CONFIG_FILE="/etc/x-ui/config.json"
    
    sudo cp $CONFIG_FILE ${CONFIG_FILE}.bak

    if ! grep -q '"inbounds"' $CONFIG_FILE; then
        echo "Inbounds section not found in config file. Adding it now."
        sudo jq '.inbounds = []' $CONFIG_FILE > temp.json && mv temp.json $CONFIG_FILE
    fi

    sudo jq ".inbounds += [{\"tag\": \"socks\", \"port\": $port, \"protocol\": \"socks\", \"settings\": {\"auth\": \"noauth\", \"udp\": true, \"userLevel\": 8}, \"sniffing\": {\"enabled\": true, \"destOverride\": [\"http\", \"tls\"], \"routeOnly\": false}}]" $CONFIG_FILE > temp.json && mv temp.json $CONFIG_FILE
}

restart_xui() {
    echo "Restarting X-UI service..."
    sudo systemctl restart x-ui
    sudo systemctl status x-ui
}

read -p "Enter the port number to be enabled: " PORT

if [[ ! "$PORT" =~ ^[0-9]+$ ]] || [ "$PORT" -le 1024 ] || [ "$PORT" -ge 65535 ]; then
    echo "Invalid port number. Please enter a valid port number between 1025 and 65535."
    exit 1
fi

check_port_usage $PORT

echo "Do you want to open the port in UFW or iptables? (Enter 'ufw' or 'iptables')"
read FIREWALL_CHOICE

if [[ "$FIREWALL_CHOICE" == "ufw" ]]; then
    open_port_ufw $PORT
elif [[ "$FIREWALL_CHOICE" == "iptables" ]]; then
    open_port_iptables $PORT
else
    echo "Invalid choice. Please choose 'ufw' or 'iptables'."
    exit 1
fi

add_inbound_rule_xui $PORT

restart_xui

echo "Port $PORT has been enabled and X-UI has been restarted."
