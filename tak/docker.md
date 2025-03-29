# Docker for TAK Setup

This document provides information on using Docker containers for TAK (Team Awareness Kit) deployment.

## Overview

Docker allows us to package TAK server and client applications with their dependencies into standardized containers. This provides several benefits:

- Consistent deployment across different environments
- Isolation from the host system
- Easy updates and rollbacks
- Simplified dependency management

## Docker Installation

### Linux (Ubuntu/Debian)

```bash
# Update package lists
sudo apt update

# Install dependencies
sudo apt install -y apt-transport-https ca-certificates curl software-properties-common

# Add Docker's official GPG key
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -

# Add Docker repository
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"

# Install Docker
sudo apt update
sudo apt install -y docker-ce docker-compose

# Add your user to the docker group (to run docker without sudo)
sudo usermod -aG docker $USER

# Apply group changes (or log out and back in)
newgrp docker
```

### macOS

1. Download and install Docker Desktop for Mac from [https://www.docker.com/products/docker-desktop](https://www.docker.com/products/docker-desktop)
2. Launch Docker Desktop and follow the setup wizard

### Windows

1. Download and install Docker Desktop for Windows from [https://www.docker.com/products/docker-desktop](https://www.docker.com/products/docker-desktop)
2. Follow the installation wizard
3. Enable WSL 2 if prompted

## Docker Compose Files

The TAK setup uses Docker Compose to manage multiple containers. The main components are:

### TAK Server Compose File

```yaml
version: '3'

services:
  tak-server:
    image: takserver/server:latest
    container_name: tak-server
    ports:
      - "8089:8089"
      - "8443:8443"
      - "8446:8446"
    volumes:
      - ./tak-data:/opt/tak/data
    restart: unless-stopped
    environment:
      - TAK_SERVER_EXTERNAL_ADDR=0.0.0.0
      # Optional custom domain
      # - TAK_SERVER_PUBLIC_URL=your-domain.com
```

### TAK Client Compose File

```yaml
version: '3'

services:
  tak-client:
    image: takclient/atak:latest
    container_name: tak-client
    ports:
      - "8080:8080"
    volumes:
      - ./tak-data:/opt/tak/data
    restart: unless-stopped
    environment:
      - TAK_SERVER_ADDRESS=server-address
```

## Docker Commands

Common Docker commands used in TAK setup:

```bash
# Start containers in the background
docker-compose up -d

# View container logs
docker logs tak-server
docker logs tak-client

# Stop containers
docker-compose down

# Update containers
docker-compose pull
docker-compose up -d

# View running containers
docker ps

# View container details
docker inspect tak-server
```

## Docker Volumes

The TAK setup uses Docker volumes to persist data:

- `tak-data`: Stores configuration files, certificates, and data

This ensures your TAK data remains intact even if containers are removed or updated.

## Troubleshooting

Common Docker issues:

1. **Permission denied**: Run Docker as sudo or add your user to the docker group
2. **Port conflicts**: Change the external port mapping if ports are already in use
3. **Memory issues**: Increase Docker's allocated memory in Docker Desktop settings
4. **Networking issues**: Check Docker's network settings and firewall rules

## Security Considerations

- Keep Docker and container images updated
- Use specific version tags rather than "latest" for production
- Set resource limits on containers
- Don't expose Docker API to the network
- Use non-root users inside containers when possible
