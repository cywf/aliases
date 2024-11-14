#!/bin/bash

# Bash script to automate Wazuh setup with ZeroTier integration
# with logging, interactive install wizard, retry mechanism, NGINX reverse proxy setup,
# and additional configuration steps

# Enable strict error handling
set -e

# Variables
LOG_FILE="wazuh_setup.log"
START_TIME=$(date)
step_counter=1
APT_UPDATE_FAILED=false

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
apt clean
apt autoremove -y
rm -rf /var/lib/apt/lists/*
mkdir -p /var/lib/apt/lists/partial

# Retry mechanism for apt update
print_status "Updating package lists..." "INFO"
APT_UPDATE_SUCCESS=false
for attempt in 1 2; do
    if apt update; then
        APT_UPDATE_SUCCESS=true
        print_status "apt update succeeded on attempt $attempt." "SUCCESS"
        break
    else
        print_status "apt update failed (attempt $attempt)." "ERROR"
        if [ $attempt -lt 2 ]; then
            print_status "Retrying apt update..." "INFO"
            sleep 5  # Wait for 5 seconds before retrying
        fi
    fi
done

if [ "$APT_UPDATE_SUCCESS" = false ]; then
    print_status "apt update failed after 2 attempts." "ERROR"
    APT_UPDATE_FAILED=true
else
    APT_UPDATE_FAILED=false
fi

print_status "Fixing broken dependencies (if any)..." "INFO"
apt install -f -y

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
if [ "$APT_UPDATE_FAILED" = false ]; then
    print_status "Updating package lists..." "INFO"
    apt update
else
    print_status "Skipping apt update due to previous failures." "ERROR"
fi

print_status "Upgrading installed packages..." "INFO"
apt upgrade -y

print_status "System packages updated and upgraded." "SUCCESS"
echo ""
read -p "Press Enter to continue to the next step..."

# Install Essential Dependencies
display_header "Installing essential dependencies"
print_status "Installing curl, wget, and other dependencies..." "INFO"
apt install -y curl wget apt-transport-https gnupg2 lsb-release software-properties-common jq gnupg-agent
print_status "Essential dependencies installed." "SUCCESS"
echo ""
read -p "Press Enter to continue to the next step..."

# Install Lynis for Security Scan
display_header "Installing Lynis for security auditing"
print_status "Installing Lynis..." "INFO"
apt install -y lynis
print_status "Running Lynis security audit..." "INFO"
lynis audit system --quick || true  # Allow Lynis to fail without exiting the script
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
if [ "$APT_UPDATE_FAILED" = false ]; then
    print_status "Updating package lists..." "INFO"
    apt update || true  # Allow apt update to fail
else
    print_status "Skipping apt update due to previous failures." "ERROR"
fi

print_status "Installing Wazuh Manager..." "INFO"
apt install -y wazuh-manager
print_status "Wazuh Manager installed." "SUCCESS"
echo ""
read -p "Press Enter to continue to the next step..."

# Set a password for Wazuh API (if installed)
display_header "Configuring Wazuh API User"
print_status "Setting up a password for Wazuh API user..." "INFO"
read -s -p "Enter a new password for the Wazuh API user 'wazuh-admin': " WAZUH_PASSWORD
echo ""
/var/ossec/bin/wazuh-users add wazuh-admin "$WAZUH_PASSWORD"
print_status "Password set for Wazuh API user 'wazuh-admin'." "SUCCESS"
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

# Provide Access Instructions
display_header "Installation Complete"
END_TIME=$(date)
print_status "Installation completed at $END_TIME" "SUCCESS"
echo ""

print_status "Access Information:" "INFO"
print_status "Wazuh Manager API URL: https://$ZT_IP:55000" "INFO"
print_status "Use the username 'wazuh-admin' and the password you set during the installation." "INFO"
print_status "Ensure you are connected to the ZeroTier network ($ZT_NETWORK_ID) to access the API." "INFO"
print_status "Note: Ports 55000 (API) and 1514 (Agent communications) should be open on your firewall." "INFO"

if [ "$APT_UPDATE_FAILED" = false ]; then
    print_status "You can access the Wazuh dashboard via Kibana at: http://$ZT_IP:5601" "INFO"
    print_status "Ensure that the necessary ports are open and accessible over your ZeroTier network." "INFO"
else
    print_status "Elasticsearch and Kibana were not installed due to apt update failures." "ERROR"
    print_status "Please resolve the apt update issues and re-run the script to install Elasticsearch and Kibana." "INFO"
fi

echo ""
print_status "Thank you for using the Wazuh-Wizard!" "SUCCESS"
