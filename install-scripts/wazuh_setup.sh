#!/bin/bash

# Bash script to automate Wazuh setup with ZeroTier integration
# with logging, interactive install wizard, and NGINX reverse proxy setup

# Enable strict error handling
set -e

# Variables
LOG_FILE="wazuh_setup.log"
START_TIME=$(date)
step_counter=1

# Function to print status messages with colors
print_status() {
    local message="$1"
    local type="$2"  # INFO, SUCCESS, ERROR
    local color=""
    case "$type" in
        INFO)
            color="\e[34m"  # Blue
            ;;
        SUCCESS)
            color="\e[32m"  # Green
            ;;
        ERROR)
            color="\e[31m"  # Red
            ;;
        *)
            color=""
            ;;
    esac
    echo -e "${color}[$(date +"%Y-%m-%d %H:%M:%S")] $message\e[0m"
    echo "[$(date +"%Y-%m-%d %H:%M:%S")] $message" >> "$LOG_FILE"
}

# Function to display headers
display_header() {
    clear
    echo "############################################################"
    echo "# Step $step_counter: $1"
    echo "############################################################"
    echo ""
    ((step_counter++))
}

# Function to handle errors
error_exit() {
    print_status "Error on line $1: $2" "ERROR"
    echo "For more details, check the log file: $LOG_FILE"
    exit 1
}

# Trap errors
trap 'error_exit ${LINENO} "$BASH_COMMAND"' ERR

# Redirect all output to the log file
exec > >(tee -a "$LOG_FILE") 2>&1

print_status "Script started at $START_TIME" "INFO"

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    print_status "This script must be run as root. Please run 'sudo bash $0'" "ERROR"
    exit 1
fi

# Display welcome message
display_header "Welcome to the Wazuh + ZeroTier Install Wizard"
echo "This script will guide you through the installation of Wazuh with ZeroTier integration."
echo "Please follow the prompts and instructions carefully."
echo ""
read -p "Press Enter to continue..."

# Preliminary System Checks and Fixes
display_header "Preliminary System Checks and Fixes"
print_status "Cleaning up and updating package lists..." "INFO"
apt-get clean
apt-get autoremove -y
rm -rf /var/lib/apt/lists/*
mkdir -p /var/lib/apt/lists/partial
apt-get update || true  # Allow failure for initial update

print_status "Fixing broken dependencies (if any)..." "INFO"
apt-get install -f -y

print_status "Updating package lists again..." "INFO"
apt-get update

print_status "System checks and fixes completed." "SUCCESS"
echo ""
read -p "Press Enter to continue to the next step..."

# Ask for Wazuh and Elasticsearch versions
display_header "Specify Wazuh and Elasticsearch Versions"
print_status "Please enter the Wazuh version you wish to install (e.g., 4.9.2):" "INFO"
read -p "Wazuh Version: " WAZUH_VERSION

print_status "Please enter the Elasticsearch version compatible with Wazuh $WAZUH_VERSION (e.g., 8.16.0):" "INFO"
read -p "Elasticsearch Version: " ELASTIC_VERSION

print_status "Wazuh version set to $WAZUH_VERSION" "SUCCESS"
print_status "Elasticsearch version set to $ELASTIC_VERSION" "SUCCESS"
echo ""
read -p "Press Enter to continue to the next step..."

# Update and Upgrade System Packages
display_header "Updating and upgrading system packages"
print_status "Updating package lists..." "INFO"
apt-get update

print_status "Upgrading installed packages..." "INFO"
apt-get upgrade -y

print_status "System packages updated and upgraded." "SUCCESS"
echo ""
read -p "Press Enter to continue to the next step..."

# Install Essential Dependencies
display_header "Installing essential dependencies"
print_status "Installing curl, wget, and other dependencies..." "INFO"
apt-get install -y curl wget apt-transport-https gnupg2 lsb-release software-properties-common jq gnupg-agent
print_status "Essential dependencies installed." "SUCCESS"
echo ""
read -p "Press Enter to continue to the next step..."

# Install Lynis for Security Scan
display_header "Installing Lynis for security auditing"
print_status "Installing Lynis..." "INFO"
apt-get install -y lynis
print_status "Running Lynis security audit..." "INFO"
lynis audit system --quick
print_status "Lynis security audit completed." "SUCCESS"
echo ""
read -p "Press Enter to continue to the next step..."

# Install ZeroTier
display_header "Installing ZeroTier"
print_status "Installing ZeroTier..." "INFO"
curl -s https://install.zerotier.com | bash
print_status "ZeroTier installed." "SUCCESS"

# Prompt user for ZeroTier Network ID
print_status "Please enter your ZeroTier Network ID." "INFO"
read -p "ZeroTier Network ID: " ZT_NETWORK_ID

# Join ZeroTier Network
print_status "Joining ZeroTier network $ZT_NETWORK_ID..." "INFO"
zerotier-cli join $ZT_NETWORK_ID
print_status "Joined ZeroTier network. Please authorize this device in your ZeroTier Central dashboard." "INFO"
echo ""
read -p "Press Enter to continue once authorized..."

# Retrieve ZeroTier IP Address
display_header "Retrieving ZeroTier IP address"
print_status "Attempting to retrieve ZeroTier IP address..." "INFO"
ZT_IP=$(zerotier-cli listnetworks -j | jq -r '.[] | select(.nwid=="'"$ZT_NETWORK_ID"'") | .assignedAddresses[0]' | cut -d'/' -f1)

if [ -z "$ZT_IP" ]; then
    print_status "Could not automatically retrieve your ZeroTier IP address." "ERROR"
    read -p "If you know your ZeroTier IP address, please enter it now (or press Enter to exit): " ZT_IP
    if [ -z "$ZT_IP" ]; then
        print_status "ZeroTier IP address is required for configuration. Exiting." "ERROR"
        exit 1
    fi
else
    print_status "ZeroTier IP address is $ZT_IP" "SUCCESS"
fi
echo ""
read -p "Press Enter to continue to the next step..."

# Ensure ZeroTier service is enabled and running
display_header "Configuring ZeroTier service"
print_status "Enabling and starting ZeroTier service..." "INFO"
systemctl enable zerotier-one
systemctl start zerotier-one
print_status "ZeroTier service is enabled and running." "SUCCESS"
echo ""
read -p "Press Enter to continue to the next step..."

# Add Wazuh repository and GPG key
display_header "Adding Wazuh repository and GPG key"
print_status "Adding Wazuh GPG key..." "INFO"
curl -s https://packages.wazuh.com/key/GPG-KEY-WAZUH | apt-key add -
print_status "Adding Wazuh repository..." "INFO"
echo "deb https://packages.wazuh.com/$WAZUH_VERSION/apt/ stable main" | tee /etc/apt/sources.list.d/wazuh.list
print_status "Wazuh repository added." "SUCCESS"
echo ""
read -p "Press Enter to continue to the next step..."

# Update apt and install Wazuh Manager
display_header "Installing Wazuh Manager"
print_status "Updating package lists..." "INFO"
apt-get update

print_status "Installing Wazuh Manager..." "INFO"
apt-get install -y wazuh-manager
print_status "Wazuh Manager installed." "SUCCESS"
echo ""
read -p "Press Enter to continue to the next step..."

# Add Elasticsearch GPG key and repository
display_header "Adding Elasticsearch repository and GPG key"
print_status "Adding Elasticsearch GPG key..." "INFO"
wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch | apt-key add -

print_status "Installing apt-transport-https..." "INFO"
apt-get install -y apt-transport-https

print_status "Adding Elasticsearch repository..." "INFO"
echo "deb https://artifacts.elastic.co/packages/$ELASTIC_VERSION/apt stable main" | tee /etc/apt/sources.list.d/elastic-$ELASTIC_VERSION.list
print_status "Elasticsearch repository added." "SUCCESS"
echo ""
read -p "Press Enter to continue to the next step..."

# Update apt and install Elasticsearch OSS
display_header "Installing Elasticsearch OSS $ELASTIC_VERSION"
print_status "Updating package lists..." "INFO"
apt-get update

print_status "Installing Elasticsearch..." "INFO"
apt-get install -y elasticsearch-oss=$ELASTIC_VERSION
print_status "Elasticsearch installed." "SUCCESS"
echo ""
read -p "Press Enter to continue to the next step..."

# Configure Elasticsearch
display_header "Configuring Elasticsearch"
print_status "Configuring Elasticsearch settings..." "INFO"
cat >> /etc/elasticsearch/elasticsearch.yml <<EOL
network.host: 0.0.0.0
http.port: 9200
discovery.type: single-node
EOL
print_status "Elasticsearch configured." "SUCCESS"
echo ""
read -p "Press Enter to continue to the next step..."

# Enable and Start Elasticsearch
display_header "Starting Elasticsearch service"
print_status "Enabling and starting Elasticsearch..." "INFO"
systemctl daemon-reload
systemctl enable elasticsearch
systemctl start elasticsearch
print_status "Elasticsearch service is enabled and running." "SUCCESS"
echo ""
read -p "Press Enter to continue to the next step..."

# Install Kibana OSS
display_header "Installing Kibana OSS $ELASTIC_VERSION"
print_status "Installing Kibana..." "INFO"
apt-get install -y kibana-oss=$ELASTIC_VERSION
print_status "Kibana installed." "SUCCESS"
echo ""
read -p "Press Enter to continue to the next step..."

# Configure Kibana
display_header "Configuring Kibana"
print_status "Configuring Kibana settings..." "INFO"
cat >> /etc/kibana/kibana.yml <<EOL
server.host: "0.0.0.0"
elasticsearch.hosts: ["http://localhost:9200"]
EOL
print_status "Kibana configured." "SUCCESS"
echo ""
read -p "Press Enter to continue to the next step..."

# Enable and Start Kibana
display_header "Starting Kibana service"
print_status "Enabling and starting Kibana..." "INFO"
systemctl daemon-reload
systemctl enable kibana
systemctl start kibana
print_status "Kibana service is enabled and running." "SUCCESS"
echo ""
read -p "Press Enter to continue to the next step..."

# Install NGINX and Configure Reverse Proxy
display_header "Installing and Configuring NGINX Reverse Proxy"
print_status "Installing NGINX..." "INFO"
apt-get install -y nginx

print_status "Configuring NGINX as a reverse proxy for Kibana..." "INFO"
cat > /etc/nginx/sites-available/kibana <<EOL
server {
    listen 5601;
    server_name $ZT_IP;

    location / {
        proxy_pass http://localhost:5601;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
    }
}
EOL

ln -s /etc/nginx/sites-available/kibana /etc/nginx/sites-enabled/kibana
rm /etc/nginx/sites-enabled/default

print_status "Testing NGINX configuration..." "INFO"
nginx -t

print_status "Restarting NGINX..." "INFO"
systemctl restart nginx

print_status "NGINX is configured as a reverse proxy for Kibana." "SUCCESS"
echo ""
read -p "Press Enter to continue to the next step..."

# Install Wazuh Elasticsearch Plugin
display_header "Installing Wazuh Elasticsearch plugin"
print_status "Installing Wazuh Elasticsearch plugin..." "INFO"

# Construct plugin URL based on versions
WAZUH_PLUGIN_URL="https://packages.wazuh.com/$WAZUH_VERSION/elasticsearch-plugins/wazuh-elasticsearch-plugin-$WAZUH_VERSION_$ELASTIC_VERSION.zip"

print_status "Downloading Wazuh Elasticsearch plugin from $WAZUH_PLUGIN_URL" "INFO"
wget $WAZUH_PLUGIN_URL -O /tmp/wazuh-elasticsearch-plugin.zip
/usr/share/elasticsearch/bin/elasticsearch-plugin install --batch file:///tmp/wazuh-elasticsearch-plugin.zip
print_status "Wazuh Elasticsearch plugin installed." "SUCCESS"

# Restart Elasticsearch
print_status "Restarting Elasticsearch..." "INFO"
systemctl restart elasticsearch
print_status "Elasticsearch restarted." "SUCCESS"
echo ""
read -p "Press Enter to continue to the next step..."

# Install Wazuh Kibana Plugin
display_header "Installing Wazuh Kibana plugin"
print_status "Installing Wazuh Kibana plugin..." "INFO"

# Construct plugin URL based on versions
WAZUH_KIBANA_PLUGIN_URL="https://packages.wazuh.com/$WAZUH_VERSION/kibana-plugins/wazuh_kibana-$WAZUH_VERSION_$ELASTIC_VERSION.zip"

print_status "Downloading Wazuh Kibana plugin from $WAZUH_KIBANA_PLUGIN_URL" "INFO"
wget $WAZUH_KIBANA_PLUGIN_URL -O /tmp/wazuh-kibana-plugin.zip
/usr/share/kibana/bin/kibana-plugin install file:///tmp/wazuh-kibana-plugin.zip
print_status "Wazuh Kibana plugin installed." "SUCCESS"

# Restart Kibana
print_status "Restarting Kibana..." "INFO"
systemctl restart kibana
print_status "Kibana restarted." "SUCCESS"
echo ""
read -p "Press Enter to continue to the next step..."

# Start and Enable Wazuh Manager
display_header "Starting Wazuh Manager service"
print_status "Enabling and starting Wazuh Manager..." "INFO"
systemctl daemon-reload
systemctl enable wazuh-manager
systemctl start wazuh-manager
print_status "Wazuh Manager service is enabled and running." "SUCCESS"
echo ""
read -p "Press Enter to continue to the next step..."

# Verify Services Status
display_header "Verifying service statuses"
print_status "Checking Wazuh Manager status..." "INFO"
systemctl status wazuh-manager --no-pager || true
print_status "Checking Elasticsearch status..." "INFO"
systemctl status elasticsearch --no-pager || true
print_status "Checking Kibana status..." "INFO"
systemctl status kibana --no-pager || true
print_status "Checking NGINX status..." "INFO"
systemctl status nginx --no-pager || true
print_status "Service status verification completed." "SUCCESS"
echo ""
read -p "Press Enter to finish the installation..."

# Provide Access Instructions
display_header "Installation Complete"
END_TIME=$(date)
print_status "Installation completed at $END_TIME" "SUCCESS"
echo ""
print_status "You can access the Wazuh dashboard via Kibana at: http://$ZT_IP:5601" "INFO"
print_status "Alternatively, access it through the NGINX reverse proxy at: http://$ZT_IP:5601" "INFO"
print_status "Note: Ensure that the necessary ports are open and accessible over your ZeroTier network." "INFO"
print_status "You may need to configure your firewall to allow traffic on port 5601 and 9200." "INFO"
echo ""
print_status "Thank you for using the Wazuh + ZeroTier Install Wizard!" "SUCCESS"
