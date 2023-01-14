#!/bin/bash

### Date: Jan 14, 2023
### Auth: cywf
#
# Docker Installation Script
#
## Setup the repository
sudo apt-get remove docker docker-engine docker.io containerd runc
sudo apt-get update
sudo apt-get install \
    ca-certificates \
    curl \
    gnupg \
    lsb-release
#
# Add Docker’s official GPG key:
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
#
## Set up the stable repository
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
#
## Install Docker Engine
sudo apt-get update
#
# -------------------------------------------- #
# Recieving GPG error when running update?
# Your default umask may be incorrectly configured, 
# preventing detection of the repository public key file. 
# Try granting read permission for the Docker public key 
# file before updating the package index:
#
# sudo chmod a+r /etc/apt/keyrings/docker.gpg
# sudo apt-get update
# -------------------------------------------- #
#
## Install Docker Engine, Containerd, and Docker Compose
sudo apt-get install docker-ce docker-ce-cli containerd.io docker-compose-plugin
#
## Veryify that Docker Engine is installed correctly by running the hello-world image.
sudo docker run hello-world
#
# Docker Post Installation
#
## Create the docker group.
sudo groupadd docker
#
## Add your user to the docker group.
sudo usermod -aG docker $USER
#
## Log out and log back in so that your group membership is re-evaluated.
#
## Verify that you can run docker commands without sudo.
docker run hello-world
#
# -------------------------------------------- #
# If you initially ran Docker CLI commands using 
# sudo before adding your user to the docker group, 
# you may see the following error:
# 
# WARNING: Error loading config file: /home/user/.docker/config.json -
# stat /home/user/.docker/config.json: permission denied
# 
# This error indicates that the permission settings 
# for the ~/.docker/ directory are incorrect, 
# due to having used the sudo command earlier.
#
# To fix this problem, either remove the ~/.docker/ 
# directory (it’s recreated automatically, 
# but any custom settings are lost), 
# or change its ownership and permissions 
# using the following commands:
# 
# sudo chown "$USER":"$USER" /home/"$USER"/.docker -R
# sudo chmod g+rwx "$HOME/.docker" -R
# -------------------------------------------- #
#
## Start Docker on boot with systemd
sudo systemctl enable docker.service
sudo systemctl enable containerd.service
#
## To disable this behavior, use disable instead.
#
# sudo systemctl disable docker.service
# sudo systemctl disable containerd.service
#
# -------------------------------------------- #
# Configure Default Logging Driver
# Docker provides logging drivers for collecting and viewing log 
# data from all containers running on a host. The default logging 
# driver, json-file, writes log data to JSON-formatted files on 
# the host filesystem. Over time, these log files expand in size, 
# leading to potential exhaustion of disk resources.
#
# To avoid issues with overusing disk for log data, consider one of the following options:
#   - Configure the json-file logging driver to turn on log rotation
#   - Use an alternative logging driver such as the “local” logging driver that performs log rotation by default
#   - Use a logging driver that sends logs to a remote logging aggregator.
