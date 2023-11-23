#!/bin/bash

# Ensure the script is run as root
if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit
fi

# Update and upgrade packages
echo "Updating and upgrading system packages..."
apt-get update && apt-get upgrade -y

# SSH Configuration
echo "Configuring SSH..."

# Generate a random port number between 2000 and 65535 for SSH
RANDOM_PORT=$((RANDOM + 2000))

# Backup the existing sshd_config file
cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup

# Change SSH port
sed -i "s/#Port 22/Port $RANDOM_PORT/g" /etc/ssh/sshd_config

# Restrict SSH access to user 'skol' only
echo "AllowUsers skol" >> /etc/ssh/sshd_config

# Restart SSH service
systemctl restart sshd

# Security and Hardening
echo "Applying security and hardening measures..."

# Additional hardening commands can go here

echo "Setup completed. SSH is now listening on port $RANDOM_PORT"
