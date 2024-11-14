#!/bin/bash

# Bash script to automate Wazuh setup with ZeroTier integration
# with logging and visual progress indicators

# Enable strict error handling
set -e

# Variables
LOG_FILE="wazuh_setup.log"
START_TIME=$(date)

# Function to print status messages
print_status() {
    echo "[$(date +"%Y-%m-%d %H:%M:%S")] $1"
    echo "[$(date +"%Y-%m-%d %H:%M:%S")] $1" >> "$LOG_FILE"
}

# Redirect all output to the log file
exec > >(tee -a "$LOG_FILE") 2>&1

print_status "Script started at $START_TIME"

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    print_status "This script must be run as root. Please run 'sudo bash $0'"
    exit 1
fi

# Update and Upgrade System Packages
print_status "Updating and upgrading system packages..."
apt update && apt upgrade -y

# Install Essential Dependencies
print_status "Installing essential dependencies..."
apt install -y curl wget apt-transport-https gnupg2 lsb-release software-properties-common jq

# Synchronize System Time
print_status "Installing and starting NTP..."
apt install -y ntp
systemctl enable ntp
systemctl start ntp

# Install Lynis for Security Scan
print_status "Installing Lynis for security auditing..."
apt install -y lynis

print_status "Running Lynis security audit..."
lynis audit system --quick

# Install ZeroTier
print_status "Installing ZeroTier..."
curl -s https://install.zerotier.com | bash

# Prompt user for ZeroTier Network ID
read -p "Please enter your ZeroTier Network ID: " ZT_NETWORK_ID

# Join ZeroTier Network
print_status "Joining ZeroTier network $ZT_NETWORK_ID..."
zerotier-cli join $ZT_NETWORK_ID

print_status "Please authorize this device in your ZeroTier Central dashboard, then press Enter to continue..."
read -p "Press Enter to continue once authorized..."

# Retrieve ZeroTier IP Address
print_status "Retrieving ZeroTier IP address..."
ZT_IP=$(zerotier-cli listnetworks -j | jq -r '.[] | select(.nwid=="'$ZT_NETWORK_ID'") | .assignedAddresses[0]' | cut -d'/' -f1)

if [ -z "$ZT_IP" ]; then
    print_status "Could not automatically retrieve your ZeroTier IP address."
    read -p "If you know your ZeroTier IP address, please enter it now (or press Enter to exit): " ZT_IP
    if [ -z "$ZT_IP" ]; then
        print_status "ZeroTier IP address is required for configuration. Exiting."
        exit 1
    fi
else
    print_status "ZeroTier IP address is $ZT_IP"
fi

# Ensure ZeroTier service is enabled and running
print_status "Enabling and starting ZeroTier service..."
systemctl enable zerotier-one
systemctl start zerotier-one

# Add Wazuh repository and GPG key
print_status "Adding Wazuh repository and GPG key..."
curl -s https://packages.wazuh.com/key/GPG-KEY-WAZUH | apt-key add -
echo "deb https://packages.wazuh.com/4.x/apt/ stable main" > /etc/apt/sources.list.d/wazuh.list

# Update apt and install Wazuh Manager
print_status "Installing Wazuh Manager..."
apt update
apt install -y wazuh-manager

# Add Elasticsearch GPG key and repository
print_status "Adding Elasticsearch GPG key and repository..."
wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch | apt-key add -
echo "deb https://artifacts.elastic.co/packages/oss-7.x/apt stable main" > /etc/apt/sources.list.d/elastic-7.x.list

# Install Elasticsearch OSS 7.10.2
print_status "Installing Elasticsearch OSS 7.10.2..."
apt update
apt install -y elasticsearch-oss=7.10.2

# Configure Elasticsearch
print_status "Configuring Elasticsearch..."
echo "network.host: $ZT_IP" >> /etc/elasticsearch/elasticsearch.yml
echo "http.port: 9200" >> /etc/elasticsearch/elasticsearch.yml
echo "discovery.type: single-node" >> /etc/elasticsearch/elasticsearch.yml

# Enable and Start Elasticsearch
print_status "Enabling and starting Elasticsearch..."
systemctl daemon-reload
systemctl enable elasticsearch
systemctl start elasticsearch

# Install Kibana OSS 7.10.2
print_status "Installing Kibana OSS 7.10.2..."
apt install -y kibana-oss=7.10.2

# Configure Kibana
print_status "Configuring Kibana..."
echo "server.host: \"$ZT_IP\"" >> /etc/kibana/kibana.yml
echo "elasticsearch.hosts: [\"http://$ZT_IP:9200\"]" >> /etc/kibana/kibana.yml

# Enable and Start Kibana
print_status "Enabling and starting Kibana..."
systemctl daemon-reload
systemctl enable kibana
systemctl start kibana

# Install Wazuh Elasticsearch Plugin
print_status "Installing Wazuh Elasticsearch plugin..."
/usr/share/elasticsearch/bin/elasticsearch-plugin install --batch https://packages.wazuh.com/4.x/elasticsearch/wazuh-elasticsearch-plugin-4.4.0_7.10.2.zip

# Restart Elasticsearch
print_status "Restarting Elasticsearch..."
systemctl restart elasticsearch

# Install Wazuh Kibana Plugin
print_status "Installing Wazuh Kibana plugin..."
/usr/share/kibana/bin/kibana-plugin install https://packages.wazuh.com/4.x/kibana/wazuh_kibana-4.4.0_7.10.2.zip

# Restart Kibana
print_status "Restarting Kibana..."
systemctl restart kibana

# Start and Enable Wazuh Manager
print_status "Starting and enabling Wazuh Manager..."
systemctl daemon-reload
systemctl enable wazuh-manager
systemctl start wazuh-manager

# Verify Services Status
print_status "Verifying service statuses..."
print_status "Wazuh Manager Status:"
systemctl status wazuh-manager --no-pager
print_status "Elasticsearch Status:"
systemctl status elasticsearch --no-pager
print_status "Kibana Status:"
systemctl status kibana --no-pager

# Provide Access Instructions
END_TIME=$(date)
print_status "Installation complete at $END_TIME"
print_status "You can access the Wazuh dashboard via Kibana at: http://$ZT_IP:5601"
print_status "Note: If you cannot access the dashboard, ensure that the necessary ports are open and accessible over your ZeroTier network."
print_status "You may also need to configure your firewall to allow traffic on port 5601."
