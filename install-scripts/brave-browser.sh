#!/bin/bash

# Ensure the script is run with root privileges
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root"
   exit 1
fi

echo "Starting Brave browser installation script..."

# Step 1: Add the Brave repository and key
echo "Adding the Brave repository..."
sudo apt install -y curl software-properties-common apt-transport-https
curl -fsSL https://brave-browser-apt-release.s3.brave.com/brave-core.asc | sudo gpg --dearmor -o /usr/share/keyrings/brave-browser-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/brave-browser-archive-keyring.gpg] https://brave-browser-apt-release.s3.brave.com/ stable main" | sudo tee /etc/apt/sources.list.d/brave-browser-release.list

# Step 2: Update package lists
echo "Updating package lists..."
sudo apt update -y

# Step 3: Install Brave browser
echo "Installing Brave browser..."
sudo apt install -y brave-browser

# Step 4: Verify installation
if command -v brave-browser > /dev/null; then
    echo "Brave browser installed successfully!"
else
    echo "Brave browser installation failed. Please check for errors."
    exit 1
fi

echo "You can launch Brave browser by typing 'brave-browser' in your terminal or through your application menu."
