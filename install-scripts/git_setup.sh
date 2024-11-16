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
echo "Visit https://github.com/settings/keys to add the SSH key."

# Conduct SSH test
echo "Testing SSH connection to GitHub..."
ssh -T git@github.com

# Print success message
echo "GitHub setup is complete. You can now use Git with SSH on GitHub."
