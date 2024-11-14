#!/bin/bash

# Bash script to automate Wazuh setup with ZeroTier integration
# Includes options to install or uninstall Wazuh
# with logging, interactive install wizard, retry mechanism, and comprehensive error handling

# Enable strict error handling
set -e

# Variables
LOG_FILE="wazuh_setup.log"
START_TIME=$(date)
step_counter=1
MAX_RETRIES=3
TIMEOUT_BETWEEN_RETRIES=5

# Colors for output
COLOR_INFO="\e[34m"    # Blue
COLOR_SUCCESS="\e[32m" # Green
COLOR_ERROR="\e[31m"   # Red
COLOR_RESET="\e[0m"    # Reset

# Function to print status messages with colors
print_status() {
    local message="$1"
    local type="$2"  # INFO, SUCCESS, ERROR
    local color=""
    case "$type" in
        INFO)    color="$COLOR_INFO" ;;
        SUCCESS) color="$COLOR_SUCCESS" ;;
        ERROR)   color="$COLOR_ERROR" ;;
        *)       color="$COLOR_RESET" ;;
    esac
    echo -e "${color}[$(date +"%Y-%m-%d %H:%M:%S")] $message${COLOR_RESET}"
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
    print_status "For more details, check the log file: $LOG_FILE" "INFO"
    exit 1
}

# Function to retry commands
retry_command() {
    local cmd="$1"
    local description="$2"
    local max_attempts=${3:-$MAX_RETRIES}
    local attempt=1
    local timeout=$TIMEOUT_BETWEEN_RETRIES
    
    while [ $attempt -le $max_attempts ]; do
        print_status "Attempting $description (try $attempt/$max_attempts)..." "INFO"
        if eval "$cmd"; then
            print_status "$description succeeded on attempt $attempt." "SUCCESS"
            return 0
        else
            print_status "$description failed (attempt $attempt/$max_attempts)." "ERROR"
            if [ $attempt -lt $max_attempts ]; then
                print_status "Waiting ${timeout} seconds before retrying..." "INFO"
                sleep $timeout
                timeout=$((timeout * 2))  # Exponential backoff
            fi
        fi
        ((attempt++))
    done
    
    print_status "$description failed after $max_attempts attempts." "ERROR"
    return 1
}

# Function to check and fix system state
check_system_state() {
    print_status "Performing system state check..." "INFO"
    
    # Stop potentially conflicting services
    local services=("elasticsearch" "kibana" "wazuh-manager" "filebeat" "zerotier-one")
    for service in "${services[@]}"; do
        if systemctl is-active --quiet "$service" 2>/dev/null; then
            print_status "Stopping $service service..." "INFO"
            systemctl stop "$service" || true
        fi
    done
    
    # Clean package manager state
    print_status "Cleaning package manager state..." "INFO"
    apt clean || true
    apt autoremove -y || true
    rm -rf /var/lib/apt/lists/*
    mkdir -p /var/lib/apt/lists/partial
    
    # Fix broken packages
    print_status "Checking for broken packages..." "INFO"
    if ! retry_command "apt install -f -y" "Fixing broken packages"; then
        print_status "Warning: Unable to fix broken packages. Continuing anyway..." "ERROR"
    fi
    
    print_status "System state check completed." "SUCCESS"
}

# Function to validate versions
validate_versions() {
    local wazuh_version="$1"
    local elastic_version="$2"
    
    if ! [[ $wazuh_version =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        print_status "Invalid Wazuh version format. Please use X.Y.Z format (e.g., 4.9.2)" "ERROR"
        return 1
    fi
    
    if ! [[ $elastic_version =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        print_status "Invalid Elasticsearch version format. Please use X.Y.Z format (e.g., 8.16.0)" "ERROR"
        return 1
    fi
    
    return 0
}

# Function to setup repositories
setup_repositories() {
    local wazuh_version="$1"
    
    print_status "Setting up repositories..." "INFO"
    
    # Remove existing Wazuh repository files
    rm -f /etc/apt/sources.list.d/wazuh.list*
    
    # Add Wazuh repository with retry
    if ! retry_command "curl -s https://packages.wazuh.com/key/GPG-KEY-WAZUH | apt-key add -" "Adding Wazuh GPG key"; then
        return 1
    fi
    
    echo "deb https://packages.wazuh.com/$wazuh_version/apt/ stable main" | tee /etc/apt/sources.list.d/wazuh.list
    
    # Update package lists with retry
    if ! retry_command "apt update" "Updating package lists"; then
        return 1
    fi
    
    return 0
}

# Function to install ZeroTier
install_zerotier() {
    print_status "Installing ZeroTier..." "INFO"
    
    if ! retry_command "curl -s https://install.zerotier.com | bash" "Installing ZeroTier"; then
        return 1
    fi
    
    # Enable and start ZeroTier service
    systemctl enable zerotier-one
    systemctl start zerotier-one
    
    return 0
}

# Function to configure ZeroTier
configure_zerotier() {
    local network_id="$1"
    local max_wait=60  # Maximum seconds to wait for IP assignment
    
    print_status "Joining ZeroTier network $network_id..." "INFO"
    zerotier-cli join "$network_id"
    
    print_status "Waiting for IP assignment (timeout: ${max_wait}s)..." "INFO"
    local wait_time=0
    while [ $wait_time -lt $max_wait ]; do
        local zt_ip=$(zerotier-cli listnetworks -j | jq -r ".[] | select(.nwid==\"$network_id\") | .assignedAddresses[0]" | cut -d'/' -f1)
        if [ ! -z "$zt_ip" ]; then
            print_status "ZeroTier IP assigned: $zt_ip" "SUCCESS"
            echo "$zt_ip"
            return 0
        fi
        sleep 5
        wait_time=$((wait_time + 5))
    done
    
    print_status "Failed to get ZeroTier IP assignment within ${max_wait} seconds" "ERROR"
    return 1
}

# Function to install Wazuh Manager
install_wazuh_manager() {
    local wazuh_version="$1"
    
    print_status "Installing Wazuh Manager..." "INFO"
    
    if ! retry_command "apt install -y wazuh-manager" "Installing Wazuh Manager"; then
        return 1
    fi
    
    # Enable and start service
    systemctl daemon-reload
    systemctl enable wazuh-manager
    systemctl start wazuh-manager
    
    # Verify installation
    if ! systemctl is-active --quiet wazuh-manager; then
        print_status "Wazuh Manager service failed to start" "ERROR"
        return 1
    fi
    
    return 0
}

# Function to configure Wazuh API
configure_wazuh_api() {
    local password="$1"
    
    print_status "Configuring Wazuh API..." "INFO"
    
    # Create API user with retry
    if ! retry_command "/var/ossec/bin/wazuh-users add wazuh-admin -p \"$password\"" "Creating Wazuh API user"; then
        return 1
    fi
    
    return 0
}

# Comprehensive uninstall function
uninstall_wazuh() {
    print_status "Beginning Wazuh uninstallation..." "INFO"
    
    # Stop services
    local services=("wazuh-manager" "elasticsearch" "kibana" "filebeat" "zerotier-one")
    for service in "${services[@]}"; do
        if systemctl is-active --quiet "$service" 2>/dev/null; then
            print_status "Stopping $service..." "INFO"
            systemctl stop "$service"
            systemctl disable "$service"
        fi
    done
    
    # Remove packages
    print_status "Removing Wazuh packages..." "INFO"
    apt remove --purge -y wazuh-manager wazuh-api elasticsearch kibana filebeat
    
    # Clean up directories
    print_status "Cleaning up Wazuh directories..." "INFO"
    rm -rf /var/ossec/
    rm -rf /etc/wazuh/
    rm -rf /var/lib/wazuh/
    
    # Remove repository files
    rm -f /etc/apt/sources.list.d/wazuh.list*
    
    # Clean up ZeroTier if requested
    read -p "Do you want to remove ZeroTier as well? (y/n): " remove_zerotier
    if [[ $remove_zerotier =~ ^[Yy]$ ]]; then
        print_status "Removing ZeroTier..." "INFO"
        zerotier-cli leave
        apt remove --purge -y zerotier-one
        rm -rf /var/lib/zerotier-one
    fi
    
    # Final cleanup
    apt autoremove -y
    apt clean
    
    print_status "Wazuh uninstallation completed." "SUCCESS"
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
read -p "Enter your choice (1 or 2): " USER_CHOICE

case "$USER_CHOICE" in
    1)
        ACTION="install"
        ;;
    2)
        ACTION="uninstall"
        ;;
    *)
        print_status "Invalid choice. Please run the script again and select 1 or 2." "ERROR"
        exit 1
        ;;
esac

if [ "$ACTION" == "install" ]; then
    # Perform system checks and preparation
    check_system_state
    
    # Get and validate versions
    while true; do
        read -p "Enter Wazuh version (e.g., 4.9.2): " WAZUH_VERSION
        read -p "Enter Elasticsearch version (e.g., 8.16.0): " ELASTIC_VERSION
        
        if validate_versions "$WAZUH_VERSION" "$ELASTIC_VERSION"; then
            break
        fi
    done
    
    # Setup repositories
    if ! setup_repositories "$WAZUH_VERSION"; then
        print_status "Failed to setup repositories. Exiting." "ERROR"
        exit 1
    fi
    
    # Install and configure ZeroTier
    if ! install_zerotier; then
        print_status "Failed to install ZeroTier. Exiting." "ERROR"
        exit 1
    fi
    
    # Get ZeroTier network ID and configure
    read -p "Enter your ZeroTier Network ID: " ZT_NETWORK_ID
    ZT_IP=$(configure_zerotier "$ZT_NETWORK_ID")
    if [ $? -ne 0 ]; then
        print_status "Failed to configure ZeroTier. Exiting." "ERROR"
        exit 1
    fi
    
    # Install Wazuh Manager
    if ! install_wazuh_manager "$WAZUH_VERSION"; then
        print_status "Failed to install Wazuh Manager. Exiting." "ERROR"
        exit 1
    fi
    
    # Configure Wazuh API
    read -s -p "Enter a password for the Wazuh API user 'wazuh-admin': " WAZUH_PASSWORD
    echo ""
    if ! configure_wazuh_api "$WAZUH_PASSWORD"; then
        print_status "Failed to configure Wazuh API. Exiting." "ERROR"
        exit 1
    fi
    
    # Installation complete
    END_TIME=$(date)
    print_status "Installation completed successfully at $END_TIME" "SUCCESS"
    echo ""
    print_status "Access Information:" "INFO"
    print_status "Wazuh Manager API URL: https://$ZT_IP:55000" "INFO"
    print_status "Username: wazuh-admin" "INFO"
    print_status "ZeroTier Network ID: $ZT_NETWORK_ID" "INFO"
    print_status "ZeroTier IP: $ZT_IP" "INFO"
    
elif [ "$ACTION" == "uninstall" ]; then
    # Perform uninstallation
    uninstall_wazuh
fi

print_status "Script completed successfully!" "SUCCESS"
exit 0
