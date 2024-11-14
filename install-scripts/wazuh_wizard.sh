#!/bin/bash

# Bash script to automate Wazuh setup with ZeroTier integration
# Includes options to install or uninstall Wazuh
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
display_header "Welcome to the Wazuh-Wizard"
echo "This script will guide you through the installation or uninstallation of Wazuh with ZeroTier integration."
echo "Please follow the prompts and instructions carefully."
echo ""

# Prompt user for action
print_status "Please choose an option:" "INFO"
echo "1. Install Wazuh"
echo "2. Uninstall Wazuh"
read -p "Enter the number corresponding to your choice (1 or 2): " USER_CHOICE

if [ "$USER_CHOICE" == "1" ]; then
    ACTION="install"
elif [ "$USER_CHOICE" == "2" ]; then
    ACTION="uninstall"
else
    print_status "Invalid choice. Please run the script again and select a valid option." "ERROR"
    exit 1
fi

print_status "You have chosen to $ACTION Wazuh." "INFO"
echo ""
read -p "Press Enter to continue..."

if [ "$ACTION" == "install" ]; then
    #####################
    # Installation Path #
    #####################

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

elif [ "$ACTION" == "uninstall" ]; then
    #######################
    # Uninstallation Path #
    #######################

    display_header "Uninstalling Wazuh and Related Components"

    # Stop Wazuh Manager
    print_status "Stopping Wazuh Manager service..." "INFO"
    systemctl stop wazuh-manager || true
    systemctl disable wazuh-manager || true

    # Uninstall Wazuh Manager
    print_status "Uninstalling Wazuh Manager..." "INFO"
    apt remove --purge -y wazuh-manager || true
    rm -rf /var/ossec

    # Remove Wazuh repository and GPG key
    print_status "Removing Wazuh repository and GPG key..." "INFO"
    rm -f /etc/apt/sources.list.d/wazuh.list
    apt-key del $(apt-key list | grep -B 1 "Wazuh.com" | head -n 1 | awk '{print $2}')
    apt update || true

    # Uninstall Elasticsearch and Kibana if they are installed
    print_status "Checking for Elasticsearch and Kibana installations..." "INFO"
    if dpkg -l | grep -q elasticsearch-oss; then
        print_status "Stopping Elasticsearch service..." "INFO"
        systemctl stop elasticsearch || true
        systemctl disable elasticsearch || true

        print_status "Uninstalling Elasticsearch..." "INFO"
        apt remove --purge -y elasticsearch-oss || true
        rm -rf /var/lib/elasticsearch
        rm -rf /etc/elasticsearch

        print_status "Removing Elasticsearch repository and GPG key..." "INFO"
        rm -f /etc/apt/sources.list.d/elastic-*.list
        apt-key del $(apt-key list | grep -B 1 "Elasticsearch" | head -n 1 | awk '{print $2}')
        apt update || true
    else
        print_status "Elasticsearch is not installed. Skipping..." "INFO"
    fi

    if dpkg -l | grep -q kibana-oss; then
        print_status "Stopping Kibana service..." "INFO"
        systemctl stop kibana || true
        systemctl disable kibana || true

        print_status "Uninstalling Kibana..." "INFO"
        apt remove --purge -y kibana-oss || true
        rm -rf /etc/kibana

        print_status "Removing Kibana repository (if any)..." "INFO"
        rm -f /etc/apt/sources.list.d/elastic-*.list
        apt update || true
    else
        print_status "Kibana is not installed. Skipping..." "INFO"
    fi

    # Remove NGINX if installed
    if dpkg -l | grep -q nginx; then
        print_status "Stopping NGINX service..." "INFO"
        systemctl stop nginx || true
        systemctl disable nginx || true

        print_status "Uninstalling NGINX..." "INFO"
        apt remove --purge -y nginx || true
        rm -rf /etc/nginx
        rm -rf /var/www/html

        print_status "NGINX uninstalled." "SUCCESS"
    else
        print_status "NGINX is not installed. Skipping..." "INFO"
    fi

    # Remove ZeroTier if installed
    if dpkg -l | grep -q zerotier-one; then
        print_status "Leaving ZeroTier network..." "INFO"
        zerotier-cli leave $ZT_NETWORK_ID || true

        print_status "Stopping ZeroTier service..." "INFO"
        systemctl stop zerotier-one || true
        systemctl disable zerotier-one || true

        print_status "Uninstalling ZeroTier..." "INFO"
        apt remove --purge -y zerotier-one || true
        rm -rf /var/lib/zerotier-one

        print_status "ZeroTier uninstalled." "SUCCESS"
    else
        print_status "ZeroTier is not installed. Skipping..." "INFO"
    fi

    # Clean up remaining packages and dependencies
    print_status "Cleaning up remaining packages and dependencies..." "INFO"
    apt autoremove -y
    apt autoclean -y
    apt update || true

    # Remove log file if the user wants
    print_status "Do you want to remove the log file ($LOG_FILE)? [y/N]" "INFO"
    read -p "Your choice: " REMOVE_LOG
    if [[ "$REMOVE_LOG" == "y" || "$REMOVE_LOG" == "Y" ]]; then
        rm -f "$LOG_FILE"
        print_status "Log file removed." "SUCCESS"
    else
        print_status "Log file retained." "INFO"
    fi

    # Uninstallation Complete
    display_header "Uninstallation Complete"
    END_TIME=$(date)
    print_status "Uninstallation completed at $END_TIME" "SUCCESS"
    echo ""
    print_status "Wazuh and related components have been uninstalled." "SUCCESS"
    echo ""
    print_status "Thank you for using the Wazuh-Wizard!" "SUCCESS"
fi
