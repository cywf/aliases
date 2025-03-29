# ZeroTier for TAK Networking

This document provides information on using ZeroTier for TAK (Team Awareness Kit) network connectivity.

## Overview

ZeroTier creates secure, virtual networks that connect devices anywhere as if they were on the same physical network. It's ideal for TAK deployment because it:

- Works across different networks and NATs
- Provides end-to-end encryption
- Allows for controlled access to the network
- Works on multiple platforms (Linux, macOS, Windows, Android, iOS)

## ZeroTier Installation

### Linux

```bash
# Install ZeroTier
curl -s https://install.zerotier.com | sudo bash

# Join a network
sudo zerotier-cli join <network-id>

# Check status
sudo zerotier-cli status
```

### macOS

1. Download and install ZeroTier from [https://www.zerotier.com/download/](https://www.zerotier.com/download/)
2. Open the ZeroTier application
3. Join a network using the network ID

### Windows

1. Download and install ZeroTier from [https://www.zerotier.com/download/](https://www.zerotier.com/download/)
2. Open the ZeroTier application
3. Join a network using the network ID

### Mobile (for ATAK/iTAK)

1. Install ZeroTier from App Store/Google Play
2. Open the ZeroTier app
3. Join a network using the network ID

## Creating a ZeroTier Network

1. Create an account at [https://my.zerotier.com/](https://my.zerotier.com/)
2. Click "Create A Network"
3. Note the Network ID (a 16-character alphanumeric string)
4. Configure network settings:
   - Name: Give your network a descriptive name
   - Access Control: Choose "Private" for secure TAK networks
   - IPv4 Auto-Assign: Enable and set address pool (e.g., 10.244.0.0/16)
   - Flow Rules: Use default rules for most cases

## Managing ZeroTier Network

### Authorizing Devices

When devices join a private ZeroTier network, they need authorization:

1. Log in to [https://my.zerotier.com/](https://my.zerotier.com/)
2. Select your network
3. Find the device in the "Members" section
4. Check the "Auth" checkbox
5. (Optional) Assign a name to the device

### Managing Routes

To enable proper routing for TAK:

1. In your network settings, under "Managed Routes"
2. Add routes as needed for your TAK deployment
3. For TAK servers, consider adding a route to the server's subnet

## Using ZeroTier with TAK

1. Install ZeroTier on all devices (TAK server and clients)
2. Join the same ZeroTier network on all devices
3. Configure TAK to use ZeroTier IP addresses
4. Ensure firewall rules allow TAK traffic between ZeroTier addresses

## Troubleshooting

Common ZeroTier issues:

1. **Connection problems**: Check if the device is authorized in the ZeroTier network
2. **No IP assignment**: Verify the "IPv4 Auto-Assign" is enabled in network settings
3. **Routing issues**: Check your managed routes configuration
4. **Firewall blocking**: Ensure UDP port 9993 is open for ZeroTier traffic
5. **Permissions**: On Linux, ZeroTier requires root privileges (use sudo)

## Security Considerations

- Keep ZeroTier updated on all devices
- Use private networks and authorize only known devices
- Consider using ZeroTier's flow rules for additional security
- Regularly review connected devices
- Use strong passwords for your ZeroTier account
- Consider enabling 2FA for your ZeroTier account

## Performance Tips

- For large TAK deployments, consider ZeroTier Enterprise for better performance
- Use regional roots if operating in specific geographical areas
- Monitor network traffic and adjust flow rules as needed
