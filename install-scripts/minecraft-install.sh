#!/bin/bash

# Prompt for user input
read -p "Enter your ZeroTier Network ID: " ZEROTIER_NETWORK_ID
read -p "Enter the memory allocation for the Minecraft server (e.g., 4G): " MEMORY_ALLOCATION

# Create a directory for your Minecraft server and navigate to it
mkdir minecraft-server
cd minecraft-server

# Create a docker-compose.yml file
cat << EOF > docker-compose.yml
version: '3.8'

services:
  minecraft:
    image: itzg/minecraft-server:latest
    container_name: minecraft-server
    environment:
      EULA: "TRUE"
      ENABLE_MODS: "TRUE"
      TYPE: "FORGE"
      VERSION: "LATEST"
      MEMORY: "${MEMORY_ALLOCATION}"
      OVERRIDE_SERVER_PROPERTIES: "TRUE"
      ZEROTIER_NETWORK: "${ZEROTIER_NETWORK_ID}"
    ports:
      - "25565:25565"
    volumes:
      - "./data:/data"
    restart: always

EOF

# Create a directory to store server data and mods
mkdir data
mkdir data/mods

# Download and add your desired mods into the 'data/mods' directory
# Example:
# wget -P data/mods https://example.com/your-mod-file.jar

# Start the Docker container
docker-compose up -d

# Join ZeroTier network
zerotier-cli join ${ZEROTIER_NETWORK_ID}

echo "Minecraft server setup complete. Connect using the ZeroTier IP address and port 25565."

# Run the script 

chmod +x setup_minecraft_server.sh
./setup_minecraft_server.sh

