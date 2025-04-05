#!/usr/bin/env bash
#
# tailscale_manager.sh
#
# A script to install, uninstall, and configure Tailscale
# on Debian/Ubuntu-based systems, with options for headless
# or web-based authentication, and optional exit node setup.

###############################################################################
# UTILITY FUNCTIONS
###############################################################################

check_root() {
  if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root (use sudo). Exiting."
    exit 1
  fi
}

press_enter_to_continue() {
  echo
  read -r -p "Press ENTER to continue..."
}

###############################################################################
# TAILSCALE INSTALL/UNINSTALL
###############################################################################

install_tailscale() {
  echo "Installing Tailscale via apt..."

  # 1. Remove any leftover Tailscale repo list or keys (clean slate)
  rm -f /etc/apt/sources.list.d/tailscale.list
  apt-key list | grep -q "Tailscale" && apt-key del "$(apt-key list | awk '/Tailscale/{key=$2; gsub(/.*\//,"",key); print key}')"

  # 2. Add Tailscale’s official stable repository
  curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/focal.gpg | apt-key add -
  curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/focal.list | tee /etc/apt/sources.list.d/tailscale.list

  # 3. Update and install
  apt-get update
  apt-get install -y tailscale

  # 4. Enable and start the service
  systemctl enable tailscaled
  systemctl start tailscaled

  echo "Tailscale installation complete."
}

uninstall_tailscale() {
  echo "Uninstalling and purging Tailscale..."

  # 1. Stop and disable the daemon
  systemctl stop tailscaled
  systemctl disable tailscaled

  # 2. Remove Tailscale package
  apt-get purge -y tailscale
  apt-get autoremove -y

  # 3. Remove leftover state/config files
  rm -rf /var/lib/tailscale* /etc/default/tailscaled /etc/systemd/system/tailscaled.service.d

  # 4. Remove the Tailscale repository
  rm -f /etc/apt/sources.list.d/tailscale.list
  apt-key list | grep -q "Tailscale" && apt-key del "$(apt-key list | awk '/Tailscale/{key=$2; gsub(/.*\//,"",key); print key}')"
  apt-get update

  echo "Tailscale has been completely removed."
}

###############################################################################
# TAILSCALE CONFIGURATION
###############################################################################

configure_web_auth() {
  echo "Configuring Tailscale with web-based authentication..."
  # Force fresh login
  tailscale logout 2>/dev/null
  systemctl stop tailscaled
  rm -rf /var/lib/tailscale
  systemctl start tailscaled

  # --reset ensures no stale settings
  tailscale up --reset --force-reauth
  echo
  echo "If a URL is provided above, copy/paste it in your browser to authenticate."
  echo "After authenticating, check https://login.tailscale.com/admin/machines to approve or confirm the device."
}

configure_headless_auth() {
  echo "Configuring Tailscale with a headless Auth Key..."
  read -r -p "Enter your Tailscale Auth Key (tskey-...): " AUTHKEY
  if [[ -z "$AUTHKEY" ]]; then
    echo "No Auth Key entered. Returning to main menu."
    return
  fi

  tailscale logout 2>/dev/null
  systemctl stop tailscaled
  rm -rf /var/lib/tailscale
  systemctl start tailscaled

  tailscale up --reset --authkey "$AUTHKEY"
  echo
  echo "Headless authentication attempted. Check https://login.tailscale.com/admin/machines to confirm the device is active."
}

advertise_exit_node() {
  echo "Advertising this machine as an exit node..."
  tailscale up --advertise-exit-node
  echo "Exit node advertised. In the Tailscale admin console, enable exit node for this machine if required."
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
    echo " TAILSCALE MANAGER"
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
# SCRIPT ENTRY POINT
###############################################################################

check_root
main_menu
