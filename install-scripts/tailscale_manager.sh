#!/usr/bin/env bash
#
# tailscale_manager.sh
# Cross-platform installer/configurator for Tailscale (Linux + macOS)

###############################################################################
# UTILITY FUNCTIONS
###############################################################################

check_root() {
  if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS doesn't require root for Homebrew installs, only for systemctl-like actions
    return
  fi
  if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root (use sudo). Exiting."
    exit 1
  fi
}

press_enter_to_continue() {
  echo
  read -r -p "Press ENTER to continue..."
}

detect_os() {
  if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    OS="linux"
  elif [[ "$OSTYPE" == "darwin"* ]]; then
    OS="macos"
  else
    echo "Unsupported operating system: $OSTYPE"
    exit 1
  fi
}

###############################################################################
# TAILSCALE INSTALL/UNINSTALL
###############################################################################

install_tailscale() {
  if [[ $OS == "linux" ]]; then
    echo "Installing Tailscale on Linux via apt..."
    . /etc/os-release
    DISTRO="${ID:-ubuntu}"
    CODENAME="${VERSION_CODENAME:-}"
    if [[ -z "$CODENAME" ]]; then
      echo "Unable to detect OS codename from /etc/os-release."
      exit 1
    fi

    rm -f /etc/apt/sources.list.d/tailscale.list
    install -m 0755 -d /usr/share/keyrings
    curl -fsSL "https://pkgs.tailscale.com/stable/${DISTRO}/${CODENAME}.gpg" \
      | gpg --dearmor -o /usr/share/keyrings/tailscale-archive-keyring.gpg
    chmod 0644 /usr/share/keyrings/tailscale-archive-keyring.gpg
    printf 'deb [signed-by=/usr/share/keyrings/tailscale-archive-keyring.gpg] https://pkgs.tailscale.com/stable/%s %s main\n' \
      "$DISTRO" "$CODENAME" > /etc/apt/sources.list.d/tailscale.list
    apt-get update
    apt-get install -y tailscale
    systemctl enable tailscaled
    systemctl start tailscaled

  elif [[ $OS == "macos" ]]; then
    echo "Installing Tailscale on macOS via Homebrew..."
    if ! command -v brew &>/dev/null; then
      echo "Homebrew not found. Install Homebrew first from https://brew.sh, then rerun this script."
      exit 1
    fi
    brew install --cask tailscale
    sudo tailscale up
  fi

  echo "Tailscale installation complete."
}

uninstall_tailscale() {
  if [[ $OS == "linux" ]]; then
    echo "Uninstalling Tailscale on Linux..."
    systemctl stop tailscaled
    systemctl disable tailscaled
    apt-get purge -y tailscale
    apt-get autoremove -y
    rm -rf /var/lib/tailscale* /etc/default/tailscaled /etc/systemd/system/tailscaled.service.d
    rm -f /etc/apt/sources.list.d/tailscale.list
    rm -f /usr/share/keyrings/tailscale-archive-keyring.gpg
    apt-get update

  elif [[ $OS == "macos" ]]; then
    echo "Uninstalling Tailscale on macOS..."
    brew uninstall --cask tailscale || true
    sudo rm -rf /Applications/Tailscale.app ~/Library/Preferences/com.tailscale*
  fi

  echo "Tailscale has been removed."
}

###############################################################################
# TAILSCALE CONFIGURATION
###############################################################################

configure_web_auth() {
  echo "Configuring Tailscale with web-based authentication..."
  tailscale logout 2>/dev/null
  tailscale up --reset --force-reauth
  echo
  echo "If a URL is shown, open it in your browser to authenticate."
}

configure_headless_auth() {
  echo "Configuring Tailscale with headless Auth Key..."
  read -r -p "Enter your Tailscale Auth Key (tskey-...): " AUTHKEY
  [[ -z "$AUTHKEY" ]] && echo "No key entered. Returning." && return
  tailscale logout 2>/dev/null
  tailscale up --reset --authkey "$AUTHKEY"
  echo "Headless authentication attempted. Check your admin console."
}

advertise_exit_node() {
  echo "Advertising this machine as an exit node..."
  tailscale up --advertise-exit-node
  echo "Exit node advertised. Enable it in the admin console if required."
}

###############################################################################
# MENU SYSTEM
###############################################################################

configure_menu() {
  while true; do
    clear
    echo "======================================================="
    echo " TAILSCALE CONFIGURATION MENU"
    echo "======================================================="
    echo "1) Web-Based Authentication"
    echo "2) Headless Authentication (Auth Key)"
    echo "3) Advertise as Exit Node"
    echo "4) Return to Main Menu"
    echo "======================================================="
    read -r -p "Select an option [1-4]: " config_choice
    case "$config_choice" in
      1) configure_web_auth; press_enter_to_continue ;;
      2) configure_headless_auth; press_enter_to_continue ;;
      3) advertise_exit_node; press_enter_to_continue ;;
      4) break ;;
      *) echo "Invalid option. Try again."; press_enter_to_continue ;;
    esac
  done
}

main_menu() {
  while true; do
    clear
    echo "======================================================="
    echo " TAILSCALE MANAGER ($OS)"
    echo "======================================================="
    echo "1) Install Tailscale"
    echo "2) Uninstall Tailscale"
    echo "3) Configure Tailscale"
    echo "4) Quit"
    echo "======================================================="
    read -r -p "Select an option [1-4]: " choice
    case "$choice" in
      1) install_tailscale; press_enter_to_continue ;;
      2) uninstall_tailscale; press_enter_to_continue ;;
      3) configure_menu ;;
      4) echo "Goodbye!"; exit 0 ;;
      *) echo "Invalid option. Try again."; press_enter_to_continue ;;
    esac
  done
}

###############################################################################
# ENTRY POINT
###############################################################################

detect_os
check_root
main_menu
