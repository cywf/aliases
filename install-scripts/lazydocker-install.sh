#!/usr/bin/env bash
#
# lazydocker-install.sh
# A script to install lazydocker on Linux systems.
# Tested on Debian/Ubuntu, Fedora, and other derivatives.
# Adjust or extend for other distros if needed.

set -e

LAZYDOCKER_VERSION="v0.21.0"  # Change to your preferred version
BINARY_NAME="lazydocker"

# 1. Detect OS and package manager
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS_ID="$ID"
else
    echo "Unable to detect OS via /etc/os-release. Exiting."
    exit 1
fi

# 2. Determine package manager (apt, dnf, yum, etc.)
if command -v apt-get &>/dev/null; then
    PKG_MANAGER="apt-get"
elif command -v apt &>/dev/null; then
    PKG_MANAGER="apt"
elif command -v dnf &>/dev/null; then
    PKG_MANAGER="dnf"
elif command -v yum &>/dev/null; then
    PKG_MANAGER="yum"
else
    echo "No supported package manager found (apt, dnf, yum). Please install dependencies manually."
    exit 1
fi

# 3. Determine architecture (x86_64 or arm64)
ARCH=$(uname -m)
case "$ARCH" in
    x86_64)
        LAZYDOCKER_ARCH="Linux_x86_64"
        ;;
    aarch64|arm64)
        LAZYDOCKER_ARCH="Linux_arm64"
        ;;
    *)
        echo "Unsupported architecture: $ARCH"
        echo "Check https://github.com/jesseduffield/lazydocker/releases for available builds."
        exit 1
        ;;
esac

# 4. Update packages and install dependencies (tar, curl) if not present
echo "Updating packages and installing dependencies (curl, tar)..."
sudo "$PKG_MANAGER" update -y
sudo "$PKG_MANAGER" install -y curl tar

# 5. Download lazydocker tarball
LAZYDOCKER_TARBALL="lazydocker_${LAZYDOCKER_VERSION}_${LAZYDOCKER_ARCH}.tar.gz"
DOWNLOAD_URL="https://github.com/jesseduffield/lazydocker/releases/download/${LAZYDOCKER_VERSION}/${LAZYDOCKER_TARBALL}"

echo "Downloading lazydocker from $DOWNLOAD_URL..."
curl -L -o "/tmp/${LAZYDOCKER_TARBALL}" "$DOWNLOAD_URL"

# 6. Extract and move lazydocker to /usr/local/bin
echo "Extracting lazydocker..."
tar -xf "/tmp/${LAZYDOCKER_TARBALL}" -C /tmp

echo "Installing lazydocker to /usr/local/bin..."
sudo mv "/tmp/${BINARY_NAME}" /usr/local/bin/
sudo chmod +x /usr/local/bin/${BINARY_NAME}

# 7. Cleanup
rm -f "/tmp/${LAZYDOCKER_TARBALL}"

# 8. Verify installation
if command -v lazydocker &>/dev/null; then
    echo "lazydocker installed successfully!"
    echo "You can now run 'lazydocker' to manage your Docker containers."
else
    echo "Something went wrong. lazydocker not found in PATH."
    exit 1
fi
