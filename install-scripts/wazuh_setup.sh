#!/bin/bash

# Ensure the script is run as root
if [ "$EUID" -ne 0 ]; then
    echo "ERROR: This script must be run as root. Please use sudo."
    exit 1
fi

# Function to install dependencies
install_dependencies() {
    echo "Installing necessary dependencies..."
    apt-get update -y
    apt-get install -y apt-transport-https ca-certificates curl software-properties-common

    # Install Docker if not installed
    if ! command -v docker &>/dev/null; then
        echo "Docker not found. Installing Docker..."
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
        add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
        apt-get update -y
        apt-get install -y docker-ce docker-compose
        echo "Docker installed successfully."
    else
        echo "Docker is already installed."
    fi

    # Verify Docker is running
    systemctl start docker
    systemctl enable docker
    echo "Docker service started and enabled."
}

# Function to create directories for Wazuh deployment
create_directories() {
    echo "Creating directories for Wazuh deployment..."
    mkdir -p ~/wazuh-docker
    cd ~/wazuh-docker
    echo "Directories created: ~/wazuh-docker"
}

# Function to create a docker-compose file
create_docker_compose() {
    echo "Creating docker-compose.yml file..."
    cat >docker-compose.yml <<EOF
version: '3.9'
services:
  wazuh-manager:
    image: wazuh/wazuh
    container_name: wazuh-manager
    ports:
      - "1514:1514/udp"
      - "55000:55000"
    volumes:
      - wazuh_data:/var/ossec/data
  wazuh-dashboard:
    image: wazuh/wazuh-dashboard
    container_name: wazuh-dashboard
    ports:
      - "443:443"
    environment:
      - DASHBOARD_USERNAME=admin
      - DASHBOARD_PASSWORD=admin
    depends_on:
      - wazuh-manager
volumes:
  wazuh_data:
EOF
    echo "docker-compose.yml created successfully."
}

# Function to run Docker containers
run_docker_compose() {
    echo "Starting Wazuh containers using Docker Compose..."
    docker-compose up -d
    if [ $? -eq 0 ]; then
        echo "Wazuh containers deployed successfully!"
        echo "Access Wazuh Dashboard at: https://localhost"
        echo "Default credentials: admin / admin"
    else
        echo "ERROR: Failed to start Wazuh containers."
        exit 1
    fi
}

# Main function to execute all steps
main() {
    echo "Starting Wazuh deployment setup..."
    install_dependencies
    create_directories
    create_docker_compose
    run_docker_compose
    echo "Wazuh deployment completed!"
}

# Execute the main function
main
