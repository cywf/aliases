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

    # Prompt for firewall choice
    read -p "Enter the firewall you want to use (ufw/iptables, default is ufw): " FIREWALL_CHOICE
    FIREWALL_CHOICE=${FIREWALL_CHOICE:-ufw} # Default to ufw if no input

    # Prompt for Zerotier Network ID
    read -p "Enter your Zerotier Network ID: " ZEROTIER_NETWORK_ID

    # Prompt for Zerotier Network IP Address (if known)
    read -p "Enter your Zerotier Network IP Address (if known, leave blank if not known): " ZEROTIER_IP_ADDRESS

    # Confirm input
    echo "Using SSH port: $SSH_PORT"
    echo "Using firewall: $FIREWALL_CHOICE"
    echo "Zerotier Network ID: $ZEROTIER_NETWORK_ID"
    if [ -n "$ZEROTIER_IP_ADDRESS" ]; then
        echo "Zerotier IP Address: $ZEROTIER_IP_ADDRESS"
    else
        echo "Zerotier IP Address: Not specified"
    fi
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
    sed -i "s/^Port [0-9]*/Port $SSH_PORT/" $SSH_CONFIG_FILE
    sed -i "s/PermitRootLogin yes/PermitRootLogin no/" $SSH_CONFIG_FILE
    sed -i "s/#PasswordAuthentication yes/PasswordAuthentication no/" $SSH_CONFIG_FILE

    systemctl restart sshd
}

# Update and upgrade the server
function update_upgrade {
    echo "Updating and upgrading server..."
    apt-get update -y && apt-get upgrade -y
}

# Configure the firewall based on user choice
function configure_firewall {
    echo "Configuring firewall..."
    if [ "$FIREWALL_CHOICE" == "ufw" ]; then
        echo "Setting up UFW..."
        apt-get install -y ufw
        ufw allow $SSH_PORT/tcp
        ufw enable
    elif [ "$FIREWALL_CHOICE" == "iptables" ]; then
        echo "Setting up iptables..."
        apt-get install -y iptables iptables-persistent
        iptables -A INPUT -p tcp --dport $SSH_PORT -j ACCEPT
        netfilter-persistent save
    else
        echo "Firewall choice not recognized or not supported. Skipping firewall configuration."
    fi
}

# Install Zerotier, Docker, TMUX, and Git
function install_packages {
    echo "Installing Zerotier, Docker, TMUX, and Git..."
    curl -s https://install.zerotier.com | bash
    apt-get install -y docker.io tmux git

    echo "Joining Zerotier Network..."
    zerotier-cli join $ZEROTIER_NETWORK_ID

    echo "Please authorize this device on the Zerotier Central web interface."
    if [ -n "$ZEROTIER_IP_ADDRESS" ]; then
        echo "After authorizing the device, assign the IP address $ZEROTIER_IP_ADDRESS via the Zerotier Central web interface."
    fi
}

# Clone the aliases repository and copy .bash_aliases
function setup_aliases {
    echo "Setting up aliases..."
    git clone https://github.com/cywf/aliases.git
    cd aliases && cp bash_aliases ~/.bash_aliases
    source ~/.bashrc
}

# Install Lynis and perform a system scan
function run_lynis_scan {
    echo "Installing Lynis..."
    apt-get install -y lynis

    echo "Running Lynis security audit..."
    lynis audit system --quiet --no-colors > /tmp/lynis.log

    # Check for warnings with High or Critical severity
    CRITICAL_WARNINGS=$(grep -E '^\s*\[WARNING\]+' /tmp/lynis.log | grep -Ei 'high|critical')

    if [ -n "$CRITICAL_WARNINGS" ]; then
        echo "Critical vulnerabilities found:"
        echo "$CRITICAL_WARNINGS"

        read -p "Would you like to attempt to remediate these issues? (yes/no): " REMEDIATE_CHOICE

        if [ "$REMEDIATE_CHOICE" == "yes" ]; then
            remediate_lynis_issues
        else
            echo "Skipping remediation."
        fi
    else
        echo "No critical vulnerabilities found."
    fi
}

# Function to attempt to remediate issues found by Lynis
function remediate_lynis_issues {
    echo "Attempting to remediate issues..."

    # Example remediations
    # Note: This is a simplified example. Proper remediation requires careful analysis.

    # Disable root login over SSH if not already done
    SSH_CONFIG_FILE="/etc/ssh/sshd_config"
    if grep -q "^PermitRootLogin yes" $SSH_CONFIG_FILE; then
        echo "Disabling root login over SSH..."
        sed -i "s/^PermitRootLogin yes/PermitRootLogin no/" $SSH_CONFIG_FILE
        systemctl restart sshd
    fi

    # Set password policy (e.g., enforce password complexity)
    if [ -f /etc/pam.d/common-password ]; then
        echo "Setting password complexity requirements..."
        sed -i 's/pam_unix.so/pam_unix.so minlen=12/' /etc/pam.d/common-password
    fi

    echo "Remediation complete."
}

# Main script execution
get_user_input
check_disk_space
check_dependencies
fix_dpkg
secure_ssh
update_upgrade
configure_firewall
install_packages
run_lynis_scan
setup_aliases

echo "Server setup complete."
