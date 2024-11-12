#!/bin/bash

# Ensure the script runs with root privileges
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 
   exit 1
fi

echo "Starting setup script..."

# Update the package manager
echo "Updating system packages..."
apt-get update -y && apt-get upgrade -y

# Install basic tools
echo "Installing essential tools..."
apt-get install -y curl wget git nano build-essential apt-transport-https ca-certificates software-properties-common

# Install Docker
echo "Installing Docker..."
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io

# Add user to Docker group
echo "Adding the current user to the Docker group..."
usermod -aG docker $USER
newgrp docker

# Verify Docker installation
docker --version && echo "Docker installed successfully!" || echo "Docker installation failed."

# Create a developer container
echo "Creating a developer environment Docker container..."
DOCKER_IMAGE="ubuntu:20.04"
CONTAINER_NAME="dev_environment"

# Pull the image if not available
if [[ "$(docker images -q $DOCKER_IMAGE 2> /dev/null)" == "" ]]; then
    echo "Pulling Docker image..."
    docker pull $DOCKER_IMAGE
fi

# Run the container with necessary configurations
docker run -dit \
  --name $CONTAINER_NAME \
  --hostname developer-container \
  -v ~/workspace:/workspace \
  -e TERM=xterm-256color \
  $DOCKER_IMAGE

# Install developer tools in the container
echo "Installing developer tools in the container..."
docker exec $CONTAINER_NAME bash -c "apt-get update && apt-get install -y git curl nano vim python3 python3-pip && mkdir /workspace"
docker exec $CONTAINER_NAME bash -c "git config --global user.name 'Your Name' && git config --global user.email 'youremail@example.com'"

# Add instructions for connecting GitHub
docker exec $CONTAINER_NAME bash -c "echo 'To connect GitHub, run: ssh-keygen -t rsa -b 4096 -C \"youremail@example.com\"' >> /workspace/README.txt"
docker exec $CONTAINER_NAME bash -c "echo 'Add your SSH key to GitHub by running: eval \"\$(ssh-agent -s)\" && ssh-add ~/.ssh/id_rsa' >> /workspace/README.txt"

echo "Setup completed successfully!"
echo "Access your developer environment by running: docker exec -it $CONTAINER_NAME bash"
