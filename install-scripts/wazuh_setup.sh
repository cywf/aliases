#!/bin/bash

# Bash script to automate Wazuh setup with ZeroTier integration

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "This script must be run as root. Please run 'sudo bash $0'"
    exit 1
fi

# Update and Upgrade System Packages
echo "Updating and upgrading system packages..."
apt update && apt upgrade -y
if [ $? -ne 0 ]; then
    echo "Error during apt update and upgrade."
    exit 1
fi

# Install Essential Dependencies
echo "Installing essential dependencies..."
apt install -y curl wget apt-transport-https gnupg2 lsb-release software-properties-common jq
if [ $? -ne 0 ]; then
    echo "Error installing essential dependencies."
    exit 1
fi

# Synchronize System Time
echo "Installing and starting NTP..."
apt install -y ntp
if [ $? -ne 0 ]; then
    echo "Error installing NTP."
    exit 1
fi
systemctl enable ntp
systemctl start ntp

# Install Lynis for Security Scan
echo "Installing Lynis for security auditing..."
apt install -y lynis
if [ $? -ne 0 ]; then
    echo "Error installing Lynis."
    exit 1
fi

echo "Running Lynis security audit..."
lynis audit system --quick

# Install ZeroTier
echo "Installing ZeroTier..."
curl -s https://install.zerotier.com | bash
if [ $? -ne 0 ]; then
    echo "Error installing ZeroTier."
    exit 1
fi

# Prompt user for ZeroTier Network ID
read -p "Please enter your ZeroTier Network ID: " ZT_NETWORK_ID

# Join ZeroTier Network
echo "Joining ZeroTier network $ZT_NETWORK_ID..."
zerotier-cli join $ZT_NETWORK_ID
if [ $? -ne 0 ]; then
    echo "Error joining ZeroTier network."
    exit 1
fi

echo "Please authorize this device in your ZeroTier Central dashboard, then press Enter to continue..."
read -p "Press Enter to continue once authorized..."

# Retrieve ZeroTier IP Address
echo "Retrieving ZeroTier IP address..."
ZT_IP=""
while [ -z "$ZT_IP" ]; do
    ZT_IP=$(zerotier-cli listnetworks -j | jq -r '.[] | select(.nwid=="'$ZT_NETWORK_ID'") | .assignedAddresses[0]' | cut -d'/' -f1)
    if [ -z "$ZT_IP" ]; then
        echo "Waiting for ZeroTier IP assignment..."
        sleep 5
    fi
done
echo "ZeroTier IP address is $ZT_IP"

# Ensure ZeroTier service is enabled and running
echo "Enabling and starting ZeroTier service..."
systemctl enable zerotier-one
systemctl start zerotier-one

# Add Wazuh repository and GPG key
echo "Adding Wazuh repository and GPG key..."
curl -s https://packages.wazuh.com/key/GPG-KEY-WAZUH | apt-key add -
echo "deb https://packages.wazuh.com/4.x/apt/ stable main" > /etc/apt/sources.list.d/wazuh.list

# Update apt and install Wazuh Manager
echo "Installing Wazuh Manager..."
apt update
apt install -y wazuh-manager
if [ $? -ne 0 ]; then
    echo "Error installing Wazuh Manager."
    exit 1
fi

# Add Elasticsearch GPG key and repository
echo "Adding Elasticsearch GPG key and repository..."
wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch | apt-key add -
echo "deb https://artifacts.elastic.co/packages/oss-7.x/apt stable main" > /etc/apt/sources.list.d/elastic-7.x.list

# Install Elasticsearch OSS 7.10.2
echo "Installing Elasticsearch OSS 7.10.2..."
apt update
apt install -y elasticsearch-oss=7.10.2
if [ $? -ne 0 ]; then
    echo "Error installing Elasticsearch."
    exit 1
fi

# Configure Elasticsearch
echo "Configuring Elasticsearch..."
echo "network.host: $ZT_IP" >> /etc/elasticsearch/elasticsearch.yml
echo "http.port: 9200" >> /etc/elasticsearch/elasticsearch.yml
echo "discovery.type: single-node" >> /etc/elasticsearch/elasticsearch.yml

# Enable and Start Elasticsearch
echo "Enabling and starting Elasticsearch..."
systemctl daemon-reload
systemctl enable elasticsearch
systemctl start elasticsearch

# Install Kibana OSS 7.10.2
echo "Installing Kibana OSS 7.10.2..."
apt install -y kibana-oss=7.10.2
if [ $? -ne 0 ]; then
    echo "Error installing Kibana."
    exit 1
fi

# Configure Kibana
echo "Configuring Kibana..."
echo "server.host: \"$ZT_IP\"" >> /etc/kibana/kibana.yml
echo "elasticsearch.hosts: [\"http://$ZT_IP:9200\"]" >> /etc/kibana/kibana.yml

# Enable and Start Kibana
echo "Enabling and starting Kibana..."
systemctl daemon-reload
systemctl enable kibana
systemctl start kibana

# Install Wazuh Elasticsearch Plugin
echo "Installing Wazuh Elasticsearch plugin..."
/usr/share/elasticsearch/bin/elasticsearch-plugin install --batch https://packages.wazuh.com/4.x/elasticsearch/wazuh-elasticsearch-plugin-4.4.0_7.10.2.zip
if [ $? -ne 0 ]; then
    echo "Error installing Wazuh Elasticsearch plugin."
    exit 1
fi

# Restart Elasticsearch
echo "Restarting Elasticsearch..."
systemctl restart elasticsearch

# Install Wazuh Kibana Plugin
echo "Installing Wazuh Kibana plugin..."
/usr/share/kibana/bin/kibana-plugin install https://packages.wazuh.com/4.x/kibana/wazuh_kibana-4.4.0_7.10.2.zip
if [ $? -ne 0 ]; then
    echo "Error installing Wazuh Kibana plugin."
    exit 1
fi

# Restart Kibana
echo "Restarting Kibana..."
systemctl restart kibana

# Start and Enable Wazuh Manager
echo "Starting and enabling Wazuh Manager..."
systemctl daemon-reload
systemctl enable wazuh-manager
systemctl start wazuh-manager

# Verify Services Status
echo "Verifying service statuses..."
echo "Wazuh Manager Status:"
systemctl status wazuh-manager --no-pager
echo "Elasticsearch Status:"
systemctl status elasticsearch --no-pager
echo "Kibana Status:"
systemctl status kibana --no-pager

# Provide Access Instructions
echo "Installation complete!"
echo "You can access the Wazuh dashboard via Kibana at: http://$ZT_IP:5601"
echo "Note: If you cannot access the dashboard, ensure that the necessary ports are open and accessible over your ZeroTier network."
echo "You may also need to configure your firewall to allow traffic on port 5601."
