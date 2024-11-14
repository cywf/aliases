#!/bin/bash

# ZeroTier IPv4 NAT Router Configuration Script
# Interactive version: Prompts user for inputs

# Colors for better visibility
GREEN="\033[1;32m"
RED="\033[1;31m"
NC="\033[0m" # No Color

echo -e "${GREEN}Welcome to the ZeroTier NAT Router Configuration Script.${NC}"

# Step 1: Check for root privileges
if [[ $EUID -ne 0 ]]; then
  echo -e "${RED}This script must be run as root. Exiting.${NC}"
  exit 1
fi

# Step 2: Prompt for user inputs
echo -e "${GREEN}Please provide the required details for the configuration.${NC}"

# ZeroTier Network ID
read -p "Enter your ZeroTier Network ID: " ZT_NETWORK_ID
if [[ -z "$ZT_NETWORK_ID" ]]; then
  echo -e "${RED}ZeroTier Network ID is required. Exiting.${NC}"
  exit 1
fi

# Gateway IP
read -p "Enter your Gateway IP (public or NAT IP of the ZeroTier gateway): " ZT_GATEWAY_IP
if [[ -z "$ZT_GATEWAY_IP" ]]; then
  echo -e "${RED}Gateway IP is required. Exiting.${NC}"
  exit 1
fi

# ZeroTier Network IP range
read -p "Enter your ZeroTier Network IP range (e.g., 10.147.17.0/24): " ZT_NETWORK_IP
if [[ -z "$ZT_NETWORK_IP" ]]; then
  echo -e "${RED}ZeroTier Network IP range is required. Exiting.${NC}"
  exit 1
fi

ZT_INTERFACE="zt+" # Default ZeroTier interface

echo -e "${GREEN}Configuration details:${NC}"
echo -e "ZeroTier Network ID: ${ZT_NETWORK_ID}"
echo -e "Gateway IP: ${ZT_GATEWAY_IP}"
echo -e "Network IP range: ${ZT_NETWORK_IP}"
read -p "Proceed with this configuration? (yes/no): " CONFIRM
if [[ "$CONFIRM" != "yes" ]]; then
  echo -e "${RED}Configuration aborted.${NC}"
  exit 1
fi

# Step 3: Check and install dependencies
echo -e "${GREEN}Checking required tools...${NC}"
REQUIRED_TOOLS=("curl" "iptables" "zerotier-cli")
for tool in "${REQUIRED_TOOLS[@]}"; do
  if ! command -v $tool &> /dev/null; then
    echo -e "${RED}Tool $tool is not installed. Installing...${NC}"
    if [[ "$tool" == "zerotier-cli" ]]; then
      curl -s https://install.zerotier.com | bash
    else
      apt-get install -y $tool || yum install -y $tool
    fi
  else
    echo -e "${GREEN}$tool is already installed.${NC}"
  fi
done

# Step 4: Enable IPv4 forwarding
echo -e "${GREEN}Configuring IPv4 forwarding...${NC}"
sysctl -w net.ipv4.ip_forward=1
echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf

# Step 5: Configure iptables
echo -e "${GREEN}Configuring iptables rules...${NC}"
# Flush existing rules
iptables -F
iptables -t nat -F
iptables -X

# NAT rules for ZeroTier
iptables -t nat -A POSTROUTING -o eth0 -s $ZT_NETWORK_IP -j SNAT --to-source $ZT_GATEWAY_IP
iptables -A FORWARD -i $ZT_INTERFACE -s $ZT_NETWORK_IP -d 0.0.0.0/0 -j ACCEPT
iptables -A FORWARD -i eth0 -s 0.0.0.0/0 -d $ZT_NETWORK_IP -j ACCEPT

# Drop all other traffic except ZeroTier
iptables -A INPUT -i $ZT_INTERFACE -s $ZT_NETWORK_IP -j ACCEPT
iptables -A INPUT -i lo -j ACCEPT
iptables -A INPUT -j DROP

# Save iptables rules
if command -v iptables-save &> /dev/null; then
  iptables-save > /etc/iptables/rules.v4
else
  echo -e "${RED}iptables-save not found. Rules will not persist after reboot.${NC}"
fi

# Step 6: Join ZeroTier Network and configure routing
echo -e "${GREEN}Joining ZeroTier Network...${NC}"
zerotier-cli join $ZT_NETWORK_ID

echo -e "${GREEN}Allowing default route override...${NC}"
zerotier-cli set $ZT_NETWORK_ID allowDefault=1

# Step 7: Restrict access to ZeroTier peers only
echo -e "${GREEN}Restricting traffic to ZeroTier peers only...${NC}"
iptables -A INPUT -i $ZT_INTERFACE -j ACCEPT
iptables -A INPUT -j DROP

# Step 8: Restart iptables service (if applicable)
if systemctl list-units --type=service | grep -q iptables; then
  echo -e "${GREEN}Restarting iptables service...${NC}"
  systemctl restart iptables
else
  echo -e "${RED}iptables service not found. Ensure rules are saved manually.${NC}"
fi

# Step 9: Verify ZeroTier status
echo -e "${GREEN}Verifying ZeroTier connection...${NC}"
zerotier-cli info
zerotier-cli listpeers

echo -e "${GREEN}ZeroTier NAT Router Configuration Complete.${NC}"
