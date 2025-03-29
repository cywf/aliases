#!/bin/bash
# TAK Setup Script Launcher
# This script checks for dependencies, installs tmux, and launches the TAK setup script

# ANSI color codes
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${GREEN}TAK Setup Launcher${NC}"
echo "Checking dependencies..."

# Clone the repository for install scripts
if [ ! -d "aliases" ]; then
    echo -e "${YELLOW}Cloning the aliases repository...${NC}"
    git clone https://github.com/cywf/aliases.git
fi

# Navigate to the install-scripts directory
cd aliases/install-scripts || exit

# Make the tmux-install.sh script executable and run it
chmod +x tmux-install.sh
./tmux-install.sh

# Navigate back to the TAK directory
cd ../../tak || exit

# Check for Python 3
if ! command -v python3 &> /dev/null; then
    echo -e "${RED}Python 3 is not installed. Please install it and try again.${NC}"
    exit 1
fi

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo -e "${YELLOW}Docker is not installed. Installing Docker...${NC}"
    
    # Detect OS and install Docker
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        # Linux
        if command -v apt-get &> /dev/null; then
            # Debian/Ubuntu
            sudo apt-get update && sudo apt-get install -y docker.io
        elif command -v dnf &> /dev/null; then
            # Fedora/RHEL
            sudo dnf install -y docker
        elif command -v pacman &> /dev/null; then
            # Arch
            sudo pacman -S --noconfirm docker
        else
            echo -e "${RED}Could not install Docker automatically. Please install it manually.${NC}"
            exit 1
        fi
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        echo -e "${RED}Please install Docker Desktop manually from https://www.docker.com/products/docker-desktop${NC}"
        exit 1
    else
        echo -e "${RED}Unsupported OS. Please install Docker manually.${NC}"
        exit 1
    fi
fi

# Start Docker service if not running
if ! sudo systemctl is-active --quiet docker; then
    echo -e "${YELLOW}Starting Docker service...${NC}"
    sudo systemctl start docker
fi

# Make the Python script executable
chmod +x tak_setup.py

# Run the setup script
echo -e "${GREEN}Starting TAK setup...${NC}"
./tak_setup.py

# Exit with the script's exit code
exit $? 
