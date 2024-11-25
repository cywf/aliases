#!/bin/bash

# Set variables for the distribution and architecture
DISTRO="noble"
ARCH="amd64"

# Define the base URL for Docker packages
BASE_URL="https://download.docker.com/linux/ubuntu/dists"

# Define the list of required Debian packages
PACKAGES=(
    "containerd.io_1.6.22-1_$ARCH.deb"
    "docker-ce_24.0.5-1~ubuntu.$DISTRO_$ARCH.deb"
    "docker-ce-cli_24.0.5-1~ubuntu.$DISTRO_$ARCH.deb"
    "docker-buildx-plugin_0.10.5-1~ubuntu.$DISTRO_$ARCH.deb"
    "docker-compose-plugin_2.22.0-1~ubuntu.$DISTRO_$ARCH.deb"
)

# Create a temporary directory for downloading packages
TEMP_DIR=$(mktemp -d)
cd $TEMP_DIR || exit 1

# Download each package
echo "Downloading Docker packages for $DISTRO ($ARCH)..."
for PACKAGE in "${PACKAGES[@]}"; do
    wget "$BASE_URL/$DISTRO/stable/binary-$ARCH/$PACKAGE" -O "$PACKAGE"
    if [ $? -ne 0 ]; then
        echo "Failed to download $PACKAGE. Exiting."
        exit 1
    fi
done

# Install downloaded packages
echo "Installing downloaded packages..."
sudo dpkg -i *.deb

# Fix missing dependencies if any
sudo apt-get install -f -y

# Clean up
echo "Cleaning up..."
cd || exit
rm -rf $TEMP_DIR

# Verify installation
echo "Verifying Docker installation..."
sudo docker run hello-world