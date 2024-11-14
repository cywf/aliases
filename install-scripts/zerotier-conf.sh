#!/bin/bash

# ZeroTier IPv4 NAT Router Configuration Script
# Includes option to allow outgoing traffic for common ports

# Colors for output
GREEN="\033[1;32m"
RED="\033[1;31m"
NC="\033[0m" # No Color

echo -e "${GREEN}Starting ZeroTier NAT Router Configuration Script...${NC}"

# Ensure script is run as root
if [[ $EUID -ne 0 ]]; then
  echo -e "${RED}This script must be run as root. Exiting.${NC}"
  exit 1
fi

# Install required tools and dependencies
echo -e "${GREEN}Checking and installing required tools...${NC}"
REQUIRED_TOOLS=("curl" "iptables" "iptables-persistent" "zerotier-cli")
for tool in "${REQUIRED_TOOLS[@]}"; do
  if ! command -v $tool &> /dev/null; then
    echo -e "${RED}Tool $tool is not installed. Installing...${NC}"
    if [[ "$tool" == "zerotier-cli" ]]; then
      curl -s https://install.zerotier.com | bash
    else
      apt-get update
      apt-get install -y $tool || yum install -y $tool
    fi
  else
    echo -e "${GREEN}$tool is already installed.${NC}"
  fi
done

# Check if iptables-persistent (netfilter-persistent) is available
echo -e "${GREEN}Configuring iptables-persistent for saving rules...${NC}"
if ! systemctl list-unit-files | grep -q netfilter-persistent; then
  echo -e "${RED}iptables-persistent (or netfilter-persistent) service not found. Installing...${NC}"
  apt-get install -y iptables-persistent || yum install -y iptables-services
fi

# Enable iptables-persistent (netfilter-persistent) service
if systemctl list-unit-files | grep -q netfilter-persistent; then
  systemctl enable netfilter-persistent
  systemctl restart netfilter-persistent
else
  echo -e "${RED}iptables-persistent service not found. Ensure rules are saved manually.${NC}"
fi

# Enable IPv4 forwarding
echo -e "${GREEN}Enabling IPv4 forwarding...${NC}"
sysctl -w net.ipv4.ip_forward=1
if ! grep -q "net.ipv4.ip_forward = 1" /etc/sysctl.conf; then
  echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
fi

# Prompt user for ZeroTier configuration details
echo -e "${GREEN}Please provide the required details for the ZeroTier configuration.${NC}"
read -p "Enter your ZeroTier Network ID: " ZT_NETWORK_ID
read -p "Enter your Gateway IP (public or NAT IP of the ZeroTier gateway): " ZT_GATEWAY_IP
read -p "Enter your ZeroTier Network IP range (e.g., 10.147.17.0/24): " ZT_NETWORK_IP

ZT_INTERFACE="zt+"

echo -e "${GREEN}Configuration details:${NC}"
echo -e "ZeroTier Network ID: ${ZT_NETWORK_ID}"
echo -e "Gateway IP: ${ZT_GATEWAY_IP}"
echo -e "Network IP range: ${ZT_NETWORK_IP}"

read -p "Would you like to allow outgoing traffic on common ports (80, 443)? (yes/no): " ALLOW_COMMON_PORTS

# Configure iptables
echo -e "${GREEN}Configuring iptables rules...${NC}"
iptables -F
iptables -t nat -F
iptables -X
iptables -t nat -A POSTROUTING -o eth0 -s $ZT_NETWORK_IP -j SNAT --to-source $ZT_GATEWAY_IP
iptables -A FORWARD -i $ZT_INTERFACE -s $ZT_NETWORK_IP -d 0.0.0.0/0 -j ACCEPT
iptables -A FORWARD -i eth0 -s 0.0.0.0/0 -d $ZT_NETWORK_IP -j ACCEPT
iptables -A INPUT -i $ZT_INTERFACE -s $ZT_NETWORK_IP -j ACCEPT
iptables -A INPUT -i lo -j ACCEPT

# Handle outgoing traffic for common ports
if [[ "$ALLOW_COMMON_PORTS" == "yes" ]]; then
  echo -e "${GREEN}Allowing outgoing traffic on ports 80 and 443...${NC}"
  iptables -A OUTPUT -p tcp --dport 80 -j ACCEPT
  iptables -A OUTPUT -p tcp --dport 443 -j ACCEPT
  iptables -A OUTPUT -p udp --dport 53 -j ACCEPT # For DNS
else
  echo -e "${RED}Blocking outgoing traffic except for essential services.${NC}"
  iptables -A OUTPUT -o $ZT_INTERFACE -j DROP
fi

iptables -A INPUT -j DROP

# Save iptables rules
echo -e "${GREEN}Saving iptables rules...${NC}"
iptables-save > /etc/iptables/rules.v4
ip6tables-save > /etc/iptables/rules.v6

# Join ZeroTier network
echo -e "${GREEN}Joining ZeroTier Network...${NC}"
zerotier-cli join $ZT_NETWORK_ID
zerotier-cli set $ZT_NETWORK_ID allowDefault=1

# Verify ZeroTier connection
echo -e "${GREEN}Verifying ZeroTier connection...${NC}"
zerotier-cli info
zerotier-cli listpeers

# Final message
echo -e "${GREEN}ZeroTier NAT Router Configuration Complete.${NC}"
echo -e "${GREEN}Your iptables rules have been saved and will persist on reboot.${NC}"
