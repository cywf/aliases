#!/usr/bin/env bash
#
# Wireshark Install & Setup
# Date: May 17, 2025
# Version: v1.0.0
#
# This script will:
#  1) Install Wireshark via your distro’s package manager
#  2) Ensure a “wireshark” group exists
#  3) Add the installing user to that group
#  4) Grant the dumpcap binary the necessary capabilities
#
set -euo pipefail
IFS=$'\n\t'

#———————————————————————————————
# Determine which user to configure
#———————————————————————————————
# If run under sudo, SUDO_USER is the real user; otherwise $USER
if [ -n "${SUDO_USER-}" ]; then
  TARGET_USER="${SUDO_USER}"
else
  TARGET_USER="${USER}"
fi
echo "→ Configuring non-root capture for user: ${TARGET_USER}"

#———————————————————————————————
# 1) Install Wireshark packages
#———————————————————————————————
install_wireshark() {
  echo "→ Installing Wireshark..."
  if command -v apt-get &>/dev/null; then
    # Preseed to allow non-root users to capture
    echo "wireshark-common wireshark-common/install-setuid boolean true" \
      | sudo debconf-set-selections
    sudo apt-get update
    sudo apt-get install -y wireshark
  elif command -v apt &>/dev/null; then
    echo "wireshark-common wireshark-common/install-setuid boolean true" \
      | sudo debconf-set-selections
    sudo apt update
    sudo apt install -y wireshark
  elif command -v dnf &>/dev/null; then
    sudo dnf install -y wireshark wireshark-gnome
  elif command -v yum &>/dev/null; then
    sudo yum install -y wireshark wireshark-gnome
  else
    echo "✗ No supported package manager found. Install Wireshark manually."
    exit 1
  fi
}

#———————————————————————————————
# 2) Ensure “wireshark” group exists
#———————————————————————————————
ensure_group() {
  if ! getent group wireshark &>/dev/null; then
    echo "→ Creating wireshark group..."
    sudo groupadd wireshark
  else
    echo "→ Group 'wireshark' already exists."
  fi
}

#———————————————————————————————
# 3) Add user to wireshark group
#———————————————————————————————
add_user_to_group() {
  echo "→ Adding ${TARGET_USER} to 'wireshark' group..."
  sudo usermod -aG wireshark "${TARGET_USER}"
}

#———————————————————————————————
# 4) Grant dumpcap the right capabilities
#———————————————————————————————
set_dumpcap_caps() {
  DUMPCAP=$(command -v dumpcap || true)
  if [ -z "${DUMPCAP}" ]; then
    echo "✗ dumpcap not found—make sure Wireshark installed correctly."
    exit 1
  fi
  echo "→ Setting capabilities on ${DUMPCAP}..."
  sudo setcap cap_net_raw,cap_net_admin+eip "${DUMPCAP}"
}

#———————————————————————————————
# Main
#———————————————————————————————
install_wireshark
ensure_group
add_user_to_group
set_dumpcap_caps

echo "✅ Wireshark installed and configured!"
echo "  • To apply group changes: log out & back in, or run 'newgrp wireshark'."
