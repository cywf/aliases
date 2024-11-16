#!/bin/bash

# -------------------------- #
# Cywf's Github Setup Script #
#                            #
#      W.I.P...              #
# -------------------------- #

# Update system package manager
echo "Updating system package manager..."
sudo apt-get update -y

# Install Git (if not already installed)
if ! command -v git &> /dev/null; then
    echo "Git not found. Installing Git..."
    sudo apt-get install git -y
else
    echo "Git is already installed."
fi

# Setup SSH configuration for GitHub
echo "Setting up SSH configuration for GitHub..."
if [ ! -f ~/.ssh/id_rsa ]; then
    ssh-keygen -t rsa -b 4096 -C "your_email@example.com" -f ~/.ssh/id_rsa -N ""
    echo "SSH key generated."
else
    echo "SSH key already exists."
fi

# Add SSH key to the ssh-agent
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_rsa

# Print SSH public key and instructions
echo "Copy the following SSH key to your GitHub account:"
cat ~/.ssh/id_rsa.pub
echo ""
echo "Instructions to add SSH key to GitHub:"
echo "1. Log in to your GitHub account."
echo "2. Go to 'Settings' by clicking on your profile picture in the top right corner."
echo "3. In the left sidebar, click on 'SSH and GPG keys'."
echo "4. Click on the 'New SSH key' button."
echo "5. In the 'Title' field, add a descriptive label for the new key (e.g., 'My Server Key')."
echo "6. Paste the copied SSH key into the 'Key' field."
echo "7. Click 'Add SSH key' to save."
echo ""
echo "Additional instructions for server administrators:"
echo "1. Ensure that the server has outbound internet access to connect to GitHub."
echo "2. If the server is behind a firewall, ensure that SSH traffic is allowed."
echo "3. Consider setting up a secure method to transfer the SSH public key from the server to your local machine if needed."
echo "4. Verify that the server's time is synchronized, as time discrepancies can cause SSH issues."
echo "5. Regularly update the server's packages and security patches to maintain security."

# Conduct SSH test
echo "Testing SSH connection to GitHub..."
ssh -T git@github.com

# Print success message
echo "GitHub setup is complete. You can now use Git with SSH on GitHub."
