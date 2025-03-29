# Tailscale for TAK Networking

This document provides information on using Tailscale for TAK (Team Awareness Kit) network connectivity.

## Overview

Tailscale is a zero-config VPN built on top of WireGuard that creates a secure network between your devices. It's excellent for TAK deployment because it:

- Provides easy setup with minimal configuration
- Works reliably across NATs and firewalls
- Offers strong encryption via WireGuard
- Integrates with existing identity providers
- Supports multi-platform deployment (Linux, macOS, Windows, Android, iOS)

## Tailscale Installation

### Linux

```bash
# For Ubuntu/Debian
curl -fsSL https://tailscale.com/install.sh | sudo bash

# Connect to your Tailscale network
sudo tailscale up

# Check status
tailscale status
```

### macOS

1. Download Tailscale from [https://tailscale.com/download](https://tailscale.com/download)
2. Install the application
3. Follow the setup prompts to authenticate

### Windows

1. Download Tailscale from [https://tailscale.com/download](https://tailscale.com/download)
2. Run the installer
3. Follow the setup prompts to authenticate

### Mobile (for ATAK/iTAK)

1. Install Tailscale from App Store/Google Play
2. Open the Tailscale app
3. Follow the setup prompts to authenticate

## Setting Up Tailscale Network

### Creating a Tailscale Account

1. Go to [https://login.tailscale.com/start](https://login.tailscale.com/start)
2. Sign up using Google, Microsoft, or email
3. Follow the onboarding instructions

### Connecting Devices

1. Install Tailscale on each device
2. Authenticate each device using your Tailscale account
3. Devices will automatically connect to your private network

### Tailscale Admin Console

The Tailscale admin console allows you to:

- View connected devices
- Manage device access
- Set up subnet routing
- Configure DNS settings
- Generate pre-authentication keys

## Using Tailscale with TAK

1. Install Tailscale on all devices (TAK server and clients)
2. Connect all devices to your Tailscale network
3. Configure TAK to use Tailscale IP addresses (100.x.y.z)
4. Ensure TAK server is accessible via its Tailscale IP

### Subnet Routing (for TAK Server)

If your TAK server needs to expose a local subnet:

1. Enable subnet routing in the Tailscale admin console
2. Run on the TAK server: `sudo tailscale up --advertise-routes=10.0.0.0/24` (replace with your subnet)
3. Approve the route in the Tailscale admin console

## Tailscale Features for TAK

### MagicDNS

Tailscale's MagicDNS feature allows devices to be addressed by name:

1. Enable MagicDNS in the Tailscale admin console
2. Use device names instead of IP addresses (e.g., `tak-server` instead of `100.x.y.z`)

### ACLs (Access Control Lists)

For more granular control:

1. Define ACLs in the Tailscale admin console
2. Restrict which devices can access the TAK server
3. Limit connectivity based on user groups

## Troubleshooting

Common Tailscale issues:

1. **Connection problems**: Run `tailscale status` to check connectivity
2. **Authentication issues**: Re-authenticate with `tailscale up`
3. **Subnet routing not working**: Verify ACLs allow subnet access
4. **Firewalls**: Ensure outbound UDP 41641 is allowed
5. **DNS issues**: Check MagicDNS settings or use IP addresses directly

## Security Considerations

- Keep Tailscale updated on all devices
- Use ACLs to restrict access within your network
- Consider enabling 2FA for your Tailscale account
- Use separate accounts for different security domains
- Review connected devices regularly
- Use ephemeral nodes for temporary access

## Performance Tips

- Enable IP forwarding on Linux: `echo 'net.ipv4.ip_forward = 1' | sudo tee -a /etc/sysctl.conf && sudo sysctl -p`
- Consider Tailscale Coordination Server (Headscale) for full control
- Use exit nodes strategically for bandwidth-intensive applications
