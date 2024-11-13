#!/bin/bash

# Ensure the script is run as root
if [ "$EUID" -ne 0 ]; then
    echo "ERROR: This script must be run as root. Please use sudo or log in as root."
    exit 1
fi

# Global checkpoint tracker
CHECKPOINT_FILE="/tmp/usb_helper_checkpoint"

# Save progress to a checkpoint file
function save_checkpoint {
    echo "$1" > "$CHECKPOINT_FILE"
}

# Load checkpoint
function load_checkpoint {
    if [ -f "$CHECKPOINT_FILE" ]; then
        cat "$CHECKPOINT_FILE"
    else
        echo "start"
    fi
}

# Clear checkpoint
function clear_checkpoint {
    rm -f "$CHECKPOINT_FILE"
}

# ASCII Loading Bar
function loading_bar {
    local message=$1
    echo -n "$message"
    for i in {1..10}; do
        echo -n "."
        sleep 0.1
    done
    echo " done."
}

# Check disk space
function check_disk_space {
    echo "Checking available disk space..."
    REQUIRED_SPACE_MB=500 # Minimum space required (in MB)
    AVAILABLE_SPACE_KB=$(df / | tail -1 | awk '{print $4}')
    AVAILABLE_SPACE_MB=$((AVAILABLE_SPACE_KB / 1024))

    if [ "$AVAILABLE_SPACE_MB" -lt "$REQUIRED_SPACE_MB" ]; then
        echo "ERROR: Insufficient disk space. Only $AVAILABLE_SPACE_MB MB available."
        echo "You can use Option 1 to extend the storage and resolve this issue."
        return 1
    fi
    echo "Sufficient disk space available: $AVAILABLE_SPACE_MB MB."
    return 0
}

# Check for required dependencies
function check_dependencies {
    echo "Gathering required tools..."
    dependencies=(lsblk mkfs.ext4 dd curl)
    for dep in "${dependencies[@]}"; do
        echo -n "Checking for $dep..."
        if ! command -v $dep &> /dev/null; then
            echo " not found."
            read -p "Would you like to install $dep? (yes/no): " INSTALL_CHOICE
            if [[ "$INSTALL_CHOICE" == "yes" ]]; then
                if ! check_disk_space; then
                    echo "ERROR: Not enough space to install $dep. Please extend storage and try again."
                    exit 1
                fi
                apt-get install -y $dep
                if [ $? -ne 0 ]; then
                    echo "ERROR: Failed to install $dep. Please check your internet connection or package manager."
                    exit 1
                fi
                loading_bar "Installing $dep"
            else
                echo "ERROR: $dep is required for this script. Exiting."
                exit 1
            fi
        else
            echo " found."
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
    save_checkpoint "extend_storage"
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
    mkfs.ext4 "$DEVICE_PATH" > /dev/null 2>&1
    if [ $? -ne 0 ]; then
        echo "ERROR: Failed to format $DEVICE_PATH. Check the device and try again."
        exit 1
    fi
    loading_bar "Formatting $DEVICE_PATH"

    # Mount the device
    MOUNT_POINT="/mnt/usb_storage"
    mkdir -p "$MOUNT_POINT"
    echo "Mounting $DEVICE_PATH at $MOUNT_POINT..."
    mount "$DEVICE_PATH" "$MOUNT_POINT" > /dev/null 2>&1
    if [ $? -ne 0 ]; then
        echo "ERROR: Failed to mount $DEVICE_PATH. Check the device and try again."
        exit 1
    fi
    loading_bar "Mounting $DEVICE_PATH"

    # Reassign temporary directories to the new storage
    echo "Reassigning temporary directories to use the new storage..."
    mkdir -p "$MOUNT_POINT/tmp" "$MOUNT_POINT/var/cache/apt"
    chmod 1777 "$MOUNT_POINT/tmp"
    mount --bind "$MOUNT_POINT/tmp" /tmp
    mount --bind "$MOUNT_POINT/var/cache/apt" /var/cache/apt

    echo "Storage has been extended. Temporary directories are now using the additional storage."
    clear_checkpoint
}

# Option 2: Stream Ubuntu Server image directly to USB
function write_ubuntu_image {
    save_checkpoint "write_ubuntu_image"
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

    # Confirm action with the user
    echo "WARNING: This will overwrite all data on $DEVICE_PATH."
    read -p "Are you sure you want to proceed? (yes/no): " CONFIRM
    if [[ "$CONFIRM" != "yes" ]]; then
        echo "Aborting."
        exit 1
    fi

    # Stream Ubuntu Server image directly to USB
    UBUNTU_URL="https://releases.ubuntu.com/24.04.1/ubuntu-24.04.1-live-server-amd64.iso"
    echo "Streaming Ubuntu Server 24.04.1 LTS image directly to $DEVICE_PATH..."
    curl -L "$UBUNTU_URL" | dd of="$DEVICE_PATH" bs=4M status=progress && sync
    if [ $? -ne 0 ]; then
        echo "ERROR: Failed to write the Ubuntu Server image to $DEVICE_PATH."
        read -p "Do you want to retry the operation? (yes/no): " RETRY
        if [[ "$RETRY" == "yes" ]]; then
            write_ubuntu_image
        else
            exit 1
        fi
    fi
    echo "Ubuntu Server image has been successfully written to $DEVICE_PATH."
    clear_checkpoint
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

# Resume from last checkpoint if available
function resume_from_checkpoint {
    local CHECKPOINT=$(load_checkpoint)
    case $CHECKPOINT in
        "extend_storage")
            echo "Resuming from Extend Storage operation..."
            extend_storage
            ;;
        "write_ubuntu_image")
            echo "Resuming from Write Ubuntu Image operation..."
            write_ubuntu_image
            ;;
        "start")
            main_menu
            ;;
        *)
            echo "Unknown checkpoint. Starting fresh."
            main_menu
            ;;
    esac
}

# Main script execution
check_dependencies
resume_from_checkpoint
