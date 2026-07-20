# Git Setup Script Documentation

## Overview

This script automates the setup of Git with SSH configuration for GitHub. It installs Git if not present, generates SSH keys, configures the SSH agent, and provides instructions for adding the SSH key to GitHub.

## Features

- Automatic Git installation
- SSH key generation for GitHub authentication
- SSH agent configuration
- GitHub SSH key setup instructions
- SSH connection testing
- Server administration guidance

## Requirements

- Ubuntu/Debian-based system
- Internet connectivity
- sudo privileges
- GitHub account

## Usage

```bash
chmod +x git_setup.sh
./git_setup.sh "Your Name" "you@example.com"
```

## What the Script Does

1. **System Update**
   - Updates the system package manager

2. **Git Installation**
   - Checks if Git is installed
   - Installs Git if missing

3. **SSH Key Generation**
   - Generates an ed25519 SSH key pair
   - Uses the required email argument as the key comment

4. **SSH Agent Configuration**
   - Starts the SSH agent
   - Adds the generated SSH key to the agent

5. **GitHub Setup Instructions**
   - Displays the public SSH key
   - Provides step-by-step instructions for adding the key to GitHub
   - Includes server administration guidance

6. **Connection Testing**
   - Tests SSH connection to GitHub
   - Displays test results

## Configuration

### Email Address

The script requires the user's Git name and email at runtime instead of using a hardcoded placeholder:

```bash
./git_setup.sh "Your Name" "you@example.com"
```

## GitHub Setup Process

1. Run the script and copy the displayed SSH public key
2. Log in to your GitHub account
3. Navigate to Settings > SSH and GPG keys
4. Click "New SSH key"
5. Add a descriptive title (e.g., "My Server Key")
6. Paste the copied SSH key
7. Click "Add SSH key"

## Server Administration

The script includes additional instructions for server administrators:
- Ensure outbound internet access to GitHub
- Configure firewalls to allow SSH traffic
- Set up secure methods for transferring SSH keys
- Synchronize server time
- Regularly update security patches

## Troubleshooting

### SSH Connection Issues

If the SSH test fails:
- Verify the SSH key was added to GitHub
- Check network connectivity to GitHub
- Ensure firewall rules allow outbound SSH

### Permission Denied Errors

If you encounter permission issues:
- Verify sudo privileges
- Check SSH key file permissions:
  ```bash
  chmod 600 ~/.ssh/id_ed25519
  chmod 644 ~/.ssh/id_ed25519.pub
  ```

### Git Not Found

If Git installation fails:
- Check internet connectivity
- Verify package manager is updated
- Manually install Git:
  ```bash
  sudo apt-get update
  sudo apt-get install git -y
  ```

## Customization

The script can be customized by modifying:
- SSH key type and bit length
- GitHub test command
- Server administration instructions