#!/bin/bash

# Ensure the script is run as root
if [ "$EUID" -ne 0 ]; then
    echo "ERROR: This script must be run as root. Please use sudo or log in as root."
    exit 1
fi

# Prompt the user for input
function get_user_input {
    echo "Please provide the necessary configuration details:"
    
    # Prompt for SSH port
    read -p "Enter the SSH port you want to use (default is 22): " SSH_PORT
    SSH_PORT=${SSH_PORT:-22} # Default to 22 if no input

    # Confirm input
    echo "Using SSH port: $SSH_PORT"
}

# Check for essential tools and install them if missing
function check_dependencies {
    echo "Checking and installing dependencies..."
    dependencies=(curl git)
    for dep in "${dependencies[@]}"; do
        if ! command -v $dep &> /dev/null; then
            echo "$dep is not installed. Installing..."
            apt-get install -y $dep
        else
            echo "$dep is already installed."
        fi
    done
}

# Ensure sufficient disk space
function check_disk_space {
    echo "Checking disk space..."
    local REQUIRED_SPACE_MB=500 # Minimum space required (in MB)
    local AVAILABLE_SPACE_MB=$(df / | tail -1 | awk '{print $4}')
    AVAILABLE_SPACE_MB=$((AVAILABLE_SPACE_MB / 1024)) # Convert to MB

    if [ "$AVAILABLE_SPACE_MB" -lt "$REQUIRED_SPACE_MB" ]; then
        echo "ERROR: Not enough disk space. Free up space and try again."
        exit 1
    fi
}

# Fix any dpkg lock or configuration issues
function fix_dpkg {
    echo "Checking for dpkg issues..."
    if [ -f /var/lib/dpkg/lock ] || [ -f /var/lib/dpkg/lock-frontend ]; then
        echo "Removing dpkg locks..."
        rm -f /var/lib/dpkg/lock /var/lib/dpkg/lock-frontend
    fi

    if ! dpkg --configure -a &>/dev/null; then
        echo "Attempting to fix dpkg issues..."
        dpkg --configure -a
    else
        echo "dpkg is in a good state."
    fi
}

# Lock down SSH
function secure_ssh {
    echo "Securing SSH..."
    local SSH_CONFIG_FILE="/etc/ssh/sshd_config"

    # Update the SSH configuration file
    sed -i "s/#Port 22/Port $SSH_PORT/" $SSH_CONFIG_FILE
    sed -i "s/PermitRootLogin yes/PermitRootLogin no/" $SSH_CONFIG_FILE
    sed -i "s/#PasswordAuthentication yes/PasswordAuthentication no/" $SSH_CONFIG_FILE

    systemctl restart sshd
}

# Update and upgrade the server
function update_upgrade {
    echo "Updating and upgrading server..."
    apt-get update -y && apt-get upgrade -y
}

# Configure the UFW firewall
function configure_ufw {
    echo "Configuring UFW firewall..."
    ufw allow $SSH_PORT/tcp
    ufw enable
}

# Install Zerotier, Docker, TMUX, and Git
function install_packages {
    echo "Installing Zerotier, Docker, TMUX, and Git..."
    curl -s https://install.zerotier.com | sudo bash
    apt-get install -y docker.io tmux git
}

# Clone the aliases repository and copy .bash_aliases
function setup_aliases {
    echo "Setting up aliases..."
    git clone https://github.com/cywf/aliases.git
    cd aliases && cp bash_aliases ~/.bash_aliases
    source ~/.bashrc
}

# Main script execution
get_user_input
check_disk_space
check_dependencies
fix_dpkg
secure_ssh
update_upgrade
configure_ufw
install_packages
setup_aliases

echo "Server setup complete."
