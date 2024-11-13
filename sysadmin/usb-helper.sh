#!/bin/bash

# Ensure the script is run as root
if [ "$EUID" -ne 0 ]; then
    echo "ERROR: This script must be run as root. Please use sudo or log in as root."
    exit 1
fi

# Check for required dependencies
function check_dependencies {
    echo "Checking for required tools..."
    dependencies=(lsblk mkfs.ext4 dd curl)
    for dep in "${dependencies[@]}"; do
        if ! command -v $dep &> /dev/null; then
            echo "$dep is not installed. Installing..."
            apt-get install -y $dep
        else
            echo "$dep is already installed."
        fi
    done
}

# Display available USB devices
function list_usb_devices {
    echo "Detecting USB devices..."
    lsblk -o NAME,SIZE,FSTYPE,LABEL,MOUNTPOINT | grep -v "sr0" | grep -E "^sd"
}

# Option 1: Extend current storage
function extend_storage {
    echo "You selected to extend storage."
    list_usb_devices

    # Prompt the user to select a device
    read -p "Enter the device name (e.g., sdb) to use as extended storage: " DEVICE
    DEVICE_PATH="/dev/$DEVICE"

    # Verify the selected device
    if [ ! -b "$DEVICE_PATH" ]; then
        echo "ERROR: Device $DEVICE_PATH does not exist. Exiting."
        exit 1
    fi

    # Format and mount the device
    echo "Formatting $DEVICE_PATH as ext4..."
    mkfs.ext4 "$DEVICE_PATH"

    # Mount the device
    MOUNT_POINT="/mnt/usb_storage"
    mkdir -p "$MOUNT_POINT"
    echo "Mounting $DEVICE_PATH at $MOUNT_POINT..."
    mount "$DEVICE_PATH" "$MOUNT_POINT"

    echo "Storage has been extended. You can now use $MOUNT_POINT as additional storage."
}

# Option 2: Write Ubuntu Server image to USB
function write_ubuntu_image {
    echo "You selected to write an Ubuntu Server image to USB."
    list_usb_devices

    # Prompt the user to select a device
    read -p "Enter the device name (e.g., sdb) to write the image to: " DEVICE
    DEVICE_PATH="/dev/$DEVICE"

    # Verify the selected device
    if [ ! -b "$DEVICE_PATH" ]; then
        echo "ERROR: Device $DEVICE_PATH does not exist. Exiting."
        exit 1
    fi

    # Download Ubuntu Server image
    UBUNTU_URL="https://releases.ubuntu.com/24.04.1/ubuntu-24.04.1-live-server-amd64.iso"
    ISO_FILE="/tmp/ubuntu-server-24.04.1.iso"
    echo "Downloading Ubuntu Server 24.04.1 LTS image..."
    curl -L -o "$ISO_FILE" "$UBUNTU_URL"

    if [ ! -f "$ISO_FILE" ]; then
        echo "ERROR: Failed to download Ubuntu Server image. Exiting."
        exit 1
    fi

    # Write the image to the USB device
    echo "Writing image to $DEVICE_PATH..."
    dd if="$ISO_FILE" of="$DEVICE_PATH" bs=4M status=progress && sync

    echo "Ubuntu Server image has been written to $DEVICE_PATH."
}

# Main menu
function main_menu {
    echo "Select an option:"
    echo "1) Extend current system storage"
    echo "2) Write Ubuntu Server image to USB"
    read -p "Enter your choice (1 or 2): " CHOICE

    case $CHOICE in
        1)
            extend_storage
            ;;
        2)
            write_ubuntu_image
            ;;
        *)
            echo "Invalid choice. Exiting."
            exit 1
            ;;
    esac
}

# Main script execution
check_dependencies
main_menu
