# TAK Server Setup Guide

This document provides information on setting up a TAK (Team Awareness Kit) server using Docker containers.

## Overview

The TAK server allows clients running ATAK, iTAK, WinTAK, or other TAK clients to connect, share locations, and exchange data. This setup uses Docker to simplify deployment and management.

## Requirements

- Linux, macOS, or Windows with Docker installed
- Internet connection
- Sufficient system resources (minimum 2GB RAM, 2 CPU cores)
- Network connectivity via ZeroTier or Tailscale

## Setup Process

The `tak_setup.py` script automates the server setup process. Key steps include:

1. Installing and configuring Docker
2. Setting up networking via ZeroTier or Tailscale
3. Deploying TAK server containers
4. Configuring certificates and authentication
5. (Optional) Setting up a custom domain

## Ports and Networking

The TAK server requires the following ports:

- TCP 8089: TAK server web interface
- TCP/UDP 8443: Main TAK server protocol
- TCP/UDP 8446: Encrypted TAK server protocol

## Configuration Files

The TAK server stores configuration in the specified data directory:

- `CoreConfig.xml`: Main server configuration
- `certs/`: SSL/TLS certificates
- `UserAuthenticationFile.xml`: User authentication

## Management

Once setup is complete, you can:

- Access the web interface at `https://<server-ip>:8089`
- Manage users via the web interface
- View server logs with `docker logs tak-server`
- Update the server with `docker-compose pull && docker-compose up -d`

## Troubleshooting

Common issues:

1. **Networking problems**: Ensure ZeroTier/Tailscale is properly configured
2. **Certificate errors**: Check the certificate generation process
3. **Docker issues**: Verify Docker is running with `docker info`
4. **Memory issues**: Ensure sufficient system resources

## Backup and Recovery

Regularly back up the data directory to prevent data loss. The backup should include:

- All configuration files
- Certificates directory
- Database files

## Security Considerations

- Keep the server behind a firewall
- Use strong passwords for the admin interface
- Regularly update Docker images
- Implement proper user authentication
- Consider using a VPN for additional security
