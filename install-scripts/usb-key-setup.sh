#!/bin/bash

# USB 2FA Key Setup Script

# Function to display a more robust loading animation
loading_room() {
    echo "Entering the Loading Room..."
    animation="|/-\\"
    for i in {1..20}; do
        echo -ne "\r${animation:i%${#animation}:1} Loading..."
        sleep 0.1
    done
    echo -e "\rDone!          "
}

# Function to perform system updates and upgrades
system_update() {
    echo "Updating system..."
    
    # Determine the package manager
    if command -v apt > /dev/null; then
        PACKAGE_MANAGER="apt"
    elif command -v yum > /dev/null; then
        PACKAGE_MANAGER="yum"
    elif command -v dnf > /dev/null; then
        PACKAGE_MANAGER="dnf"
    elif command -v pacman > /dev/null; then
        PACKAGE_MANAGER="pacman"
    else
        echo "Error: No supported package manager found."
        exit 1
    fi

    # Perform updates based on the package manager
    case $PACKAGE_MANAGER in
        apt)
            sudo apt update && sudo apt upgrade -y
            ;;
        yum)
            sudo yum update -y
            ;;
        dnf)
            sudo dnf upgrade --refresh -y
            ;;
        pacman)
            sudo pacman -Syu --noconfirm
            ;;
    esac

    # Check if the update was successful
    if [ $? -ne 0 ]; then
        echo "Error: System update failed."
        exit 1
    fi
}

# Function to install Lynis and run a system audit
install_lynis() {
    echo "Installing Lynis..."

    # Determine the package manager
    if command -v apt > /dev/null; then
        PACKAGE_MANAGER="apt"
    elif command -v yum > /dev/null; then
        PACKAGE_MANAGER="yum"
    elif command -v dnf > /dev/null; then
        PACKAGE_MANAGER="dnf"
    elif command -v pacman > /dev/null; then
        PACKAGE_MANAGER="pacman"
    else
        echo "Error: No supported package manager found."
        exit 1
    fi

    # Attempt to install Lynis using the package manager
    case $PACKAGE_MANAGER in
        apt)
            sudo apt install lynis -y
            ;;
        yum)
            sudo yum install lynis -y
            ;;
        dnf)
            sudo dnf install lynis -y
            ;;
        pacman)
            sudo pacman -S lynis --noconfirm
            ;;
    esac

    # Check if the installation was successful
    if [ $? -ne 0 ]; then
        echo "Package manager installation failed. Attempting to clone Lynis from GitHub..."
        # Fallback to cloning Lynis from GitHub
        if command -v git > /dev/null; then
            git clone https://github.com/CISOfy/lynis.git
            if [ $? -ne 0 ]; then
                echo "Error: Cloning Lynis from GitHub failed."
                exit 1
            fi
            cd lynis || exit
            sudo ./lynis audit system
            cd ..
        else
            echo "Error: Git is not installed. Cannot clone Lynis."
            exit 1
        fi
    else
        echo "Running Lynis audit..."
        sudo lynis audit system
    fi
}

# Function to install Yubikey software
install_yubikey_software() {
    echo "Installing Yubikey software..."

    # Determine the package manager
    if command -v apt > /dev/null; then
        PACKAGE_MANAGER="apt"
    elif command -v yum > /dev/null; then
        PACKAGE_MANAGER="yum"
    elif command -v dnf > /dev/null; then
        PACKAGE_MANAGER="dnf"
    elif command -v pacman > /dev/null; then
        PACKAGE_MANAGER="pacman"
    else
        echo "Error: No supported package manager found."
        exit 1
    fi

    # Attempt to install Yubikey software and libpam-u2f using the package manager
    case $PACKAGE_MANAGER in
        apt)
            sudo apt install yubikey-personalization yubikey-manager libpam-u2f -y
            ;;
        yum)
            sudo yum install yubikey-personalization yubikey-manager pam-u2f -y
            ;;
        dnf)
            sudo dnf install yubikey-personalization yubikey-manager pam-u2f -y
            ;;
        pacman)
            sudo pacman -S yubikey-personalization yubikey-manager pam-u2f --noconfirm
            ;;
    esac

    # Check if the installation was successful
    if [ $? -ne 0 ]; then
        echo "Package manager installation failed. Attempting to install Yubikey software manually..."
        
        # Fallback to manual installation
        if command -v curl > /dev/null; then
            # Download and install Yubikey Manager
            curl -LO https://developers.yubico.com/yubikey-manager-qt/Releases/yubikey-manager-qt-latest.tar.gz
            tar -xzf yubikey-manager-qt-latest.tar.gz
            cd yubikey-manager-qt-* || exit
            sudo ./install.sh
            if [ $? -ne 0 ]; then
                echo "Error: Manual installation of Yubikey Manager failed."
                exit 1
            fi
            cd ..

            # Download and install libpam-u2f
            curl -LO https://developers.yubico.com/pam-u2f/Releases/pam-u2f-latest.tar.gz
            tar -xzf pam-u2f-latest.tar.gz
            cd pam-u2f-* || exit
            ./configure
            make
            sudo make install
            if [ $? -ne 0 ]; then
                echo "Error: Manual installation of libpam-u2f failed."
                exit 1
            fi
            cd ..
        else
            echo "Error: curl is not installed. Cannot download Yubikey software."
            exit 1
        fi
    fi

    echo "Yubikey software installation complete."
}

# Function to display the menu and handle user choices
display_menu() {
    echo "Choose an option:"
    echo "1. Setup USB Key for LUKS"
    echo "2. Setup USB Key for sudo commands"
    echo "3. Setup MFA for an application"
    read -p "Enter your choice [1-3]: " choice

    case $choice in
        1)
            echo "Setting up USB Key for LUKS..."
            # Example logic for setting up USB Key for LUKS
            read -p "Enter the device path (e.g., /dev/sdX): " device
            sudo cryptsetup luksAddKey "$device"
            if [ $? -ne 0 ]; then
                echo "Error: Failed to set up USB Key for LUKS."
                exit 1
            fi
            echo "USB Key successfully set up for LUKS."
            ;;
        2)
            echo "Setting up USB Key for sudo commands..."
            # Example logic for setting up USB Key for sudo commands
            echo "auth required pam_u2f.so" | sudo tee -a /etc/pam.d/sudo
            if [ $? -ne 0 ]; then
                echo "Error: Failed to set up USB Key for sudo commands."
                exit 1
            fi
            echo "USB Key successfully set up for sudo commands."
            ;;
        3)
            echo "Setting up MFA for an application..."
            # Example logic for setting up MFA for an application
            read -p "Enter the application name: " app_name
            echo "auth required pam_u2f.so" | sudo tee -a /etc/pam.d/"$app_name"
            if [ $? -ne 0 ]; then
                echo "Error: Failed to set up MFA for $app_name."
                exit 1
            fi
            echo "MFA successfully set up for $app_name."
            ;;
        *)
            echo "Invalid choice. Exiting."
            exit 1
            ;;
    esac
}

# Function to setup the USB key for user accounts
setup_usb_for_user_accounts() {
    echo "Setting up USB key for user accounts..."

    # Step 1: Create the Yubico configuration directory
    mkdir -p ~/.config/Yubico

    # Step 2: Generate the U2F keys configuration
    pamu2fcfg > ~/.config/Yubico/u2f_keys
    if [ $? -ne 0 ]; then
        echo "Error: Failed to generate U2F keys configuration."
        exit 1
    fi

    echo "Please insert your USB key and press Enter to continue..."
    read -r

    # Step 3: Check if the system recognizes the USB key
    if ! lsusb | grep -i "Yubico" > /dev/null; then
        echo "Error: USB key not detected. Please ensure it is properly connected."
        exit 1
    fi

    # Step 4-6: Update PAM configuration for sudo
    PAM_SUDO_FILE="/etc/pam.d/sudo"
    if ! grep -q "auth required pam_u2f.so" "$PAM_SUDO_FILE"; then
        echo "auth required pam_u2f.so" | sudo tee -a "$PAM_SUDO_FILE"
    fi

    # Step 7-8: Update PAM configuration for gdm-password
    PAM_GDM_FILE="/etc/pam.d/gdm-password"
    if ! grep -q "auth required pam_u2f.so" "$PAM_GDM_FILE"; then
        echo "auth required pam_u2f.so" | sudo tee -a "$PAM_GDM_FILE"
    fi

    # Step 9-10: Update PAM configuration for login
    PAM_LOGIN_FILE="/etc/pam.d/login"
    if ! grep -q "auth required pam_u2f.so" "$PAM_LOGIN_FILE"; then
        echo "auth required pam_u2f.so" | sudo tee -a "$PAM_LOGIN_FILE"
    fi

    echo "Configuration complete. You should now be able to use your USB key for authentication."
}

setup_fido2_ssh() {
    echo "Setting up USB for SSH with FIDO2-compatible devices..."

    # Step 1: Update system
    echo "Updating system..."
    if command -v apt > /dev/null; then
        sudo apt update && sudo apt upgrade -y
    elif command -v yum > /dev/null; then
        sudo yum update -y
    elif command -v dnf > /dev/null; then
        sudo dnf upgrade --refresh -y
    elif command -v pacman > /dev/null; then
        sudo pacman -Syu --noconfirm
    else
        echo "Error: No supported package manager found."
        exit 1
    fi

    # Step 2: Install libfido2-dev
    echo "Installing libfido2-dev..."
    if command -v apt > /dev/null; then
        sudo apt install libfido2-dev -y
    elif command -v yum > /dev/null; then
        sudo yum install libfido2-devel -y
    elif command -v dnf > /dev/null; then
        sudo dnf install libfido2-devel -y
    elif command -v pacman > /dev/null; then
        sudo pacman -S libfido2 --noconfirm
    else
        echo "Error: No supported package manager found."
        exit 1
    fi

    # Step 3: Create SSH Key
    echo "Creating SSH key..."
    ssh-keygen -t ed25519-sk -C "$(hostname)-$(date +'%d-%m-%Y')-yubikey1"
    if [ $? -ne 0 ]; then
        echo "Error: SSH key generation failed."
        exit 1
    fi

    # Step 4: User presses Yubikey bio
    echo "Please press your Yubikey button when prompted."

    # Step 5: Copy SSH Pub key to destination
    read -p "Enter the destination IP address or hostname (default: github.com): " destination
    destination=${destination:-github.com}

    if [ "$destination" = "github.com" ]; then
        echo "Setting up SSH key for GitHub..."
        echo "Please log in to your GitHub account and add the following SSH key:"
        cat ~/.ssh/id_ed25519_sk.pub
        echo "Visit https://github.com/settings/keys to add your SSH key."
        read -p "Press Enter after adding the SSH key to GitHub..."
    else
        ssh-copy-id -i ~/.ssh/id_ed25519_sk.pub "$destination"
        if [ $? -ne 0 ]; then
            echo "Error: Failed to copy SSH public key to destination."
            exit 1
        fi
    fi

    # Step 6: Conduct test
    echo "Conducting SSH test..."
    ssh -T git@github.com
    if [ $? -ne 0 ]; then
        echo "Error: SSH test failed."
        exit 1
    fi

    # Step 7: Edit sshd_config to disable password authentication
    echo "Disabling password authentication in sshd_config..."
    sudo sed -i 's/^#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config

    # Step 8: Restart SSH service
    echo "Restarting SSH service..."
    sudo systemctl restart ssh

    # Step 9: Conduct final SSH test
    echo "Conducting final SSH test..."
    ssh -T git@github.com
    if [ $? -ne 0 ]; then
        echo "Error: Final SSH test failed."
        exit 1
    fi

    echo "FIDO2 SSH setup complete. Your Yubikey should blink during authentication."
}

# Function to setup USB for SSH with non-FIDO2 Yubikey
setup_non_fido2_ssh() {
    echo "Setting up USB for SSH with non-FIDO2 Yubikey..."

    # Step 1: Install Yubikey repository and update
    echo "Adding Yubico repository and updating..."
    sudo add-apt-repository ppa:yubico/stable -y
    sudo apt update

    # Step 2: Install Yubico Package
    echo "Installing libpam-yubico..."
    sudo apt install libpam-yubico -y
    if [ $? -ne 0 ]; then
        echo "Error: Failed to install libpam-yubico."
        exit 1
    fi

    # Step 3: Edit authorized_yubikeys
    AUTH_YUBIKEYS_FILE="/etc/ssh/authorized_yubikeys"
    echo "Configuring authorized Yubikeys..."
    sudo touch "$AUTH_YUBIKEYS_FILE"
    sudo nano "$AUTH_YUBIKEYS_FILE"
    echo "Please add each user and their Yubikey prefix to $AUTH_YUBIKEYS_FILE."

    # Step 5: Guide user to get API key
    echo "Please visit https://upgrade.yubico.com/getapikey to obtain your API key."
    echo "Note down your Client ID and Secret Key. It's recommended to save them in a secure password manager like Bitwarden."

    # Step 6: Edit PAM file
    PAM_SSHD_FILE="/etc/pam.d/sshd"
    echo "Editing PAM configuration for SSH..."
    read -p "Enter your Client ID: " client_id
    read -p "Enter your Secret Key: " secret_key
    echo "auth required pam_yubico.so id=$client_id key=$secret_key authfile=$AUTH_YUBIKEYS_FILE" | sudo tee -a "$PAM_SSHD_FILE"

    # Step 7: Edit SSH configuration
    SSHD_CONFIG_FILE="/etc/ssh/sshd_config"
    echo "Editing SSH configuration..."
    sudo sed -i 's/^#ChallengeResponseAuthentication no/ChallengeResponseAuthentication yes/' "$SSHD_CONFIG_FILE"
    sudo sed -i 's/^#UsePAM no/UsePAM yes/' "$SSHD_CONFIG_FILE"

    # Step 8: Restart SSH service
    echo "Restarting SSH service..."
    sudo systemctl restart ssh

    # Step 9: Test SSH connection
    echo "Testing SSH connection..."
    echo "Open a new terminal and attempt to SSH into this machine. Your Yubikey should blink during authentication."

    echo "Non-FIDO2 SSH setup complete. SSH is now configured to use your Yubikey."
}

# Main script execution
loading_room
system_update
install_lynis
install_yubikey_software

# Display menu for USB key setup options
display_menu

# Prompt user for SSH setup option
echo "Choose an SSH setup option:"
echo "1. FIDO2 SSH Setup"
echo "2. Non-FIDO2 SSH Setup"
read -p "Enter your choice [1-2]: " ssh_choice

case $ssh_choice in
    1)
        setup_fido2_ssh
        ;;
    2)
        setup_non_fido2_ssh
        ;;
    *)
        echo "Invalid choice. Skipping SSH setup."
        ;;
esac

# Setup USB key for user accounts
setup_usb_for_user_accounts

echo "Setup complete."