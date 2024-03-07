#!/bin/bash

# Lock down SSH
function secure_ssh {
    echo "Securing SSH..."
    local SSH_CONFIG_FILE="/etc/ssh/sshd_config"

    # Change the SSH port
    local SSH_PORT="YOUR_NEW_SSH_PORT" # Change this to your desired port
    sed -i "s/#Port 22/Port $SSH_PORT/" $SSH_CONFIG_FILE

    # Disable root login over SSH
    sed -i "s/PermitRootLogin yes/PermitRootLogin no/" $SSH_CONFIG_FILE

    # Disable SSH password authentication
    sed -i "s/#PasswordAuthentication yes/PasswordAuthentication no/" $SSH_CONFIG_FILE

    # Restart SSH service
    systemctl restart sshd
}

# Update and upgrade the server
function update_upgrade {
    echo "Updating and upgrading server..."
    apt-get update && apt-get upgrade -y
}

# Configure the UFW firewall
function configure_ufw {
    echo "Configuring UFW firewall..."
    ufw allow $SSH_PORT/tcp # Allow your new SSH port
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

# Run the functions
secure_ssh
update_upgrade
configure_ufw
install_packages
setup_aliases

echo "Server setup complete."
