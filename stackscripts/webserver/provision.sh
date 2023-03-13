#!/bin/bash

# Linode Access Token
LINODE_ACCESS_TOKEN="your-linode-access-token"

# Create a new Linode Instance
INSTANCE_TYPE="g6-nanode-1"
REGION="us-west"
INSTANCE_LABEL="label-example"
INSTANCE_IMAGE="linode/ubuntu20.04"
INSTANCE_ROOT_PASS="your-instance-root-password"
INSTANCE_SSH_KEY="your-ssh-public-key"
INSTANCE_VOLUMES="none"
LINODE_API_URL="https://api.linode.com/v4/linode/instances"

curl -H "Content-Type: application/json" \
    -H "Authorization: Bearer $LINODE_ACCESS_TOKEN" \
    -d '{"region": "'"$REGION"'","type": "'"$INSTANCE_TYPE"'","image": "'"$INSTANCE_IMAGE"'","root_pass": "'"$INSTANCE_ROOT_PASS"'","label": "'"$INSTANCE_LABEL"'","ssh_keys": ["'"$INSTANCE_SSH_KEY"'"],"authorized_users": ["root"],"backups_enabled": false,"booleans": {"private_ip": true},"volumes": ["'"$INSTANCE_VOLUMES"'"]}' \
    -X POST \
    $LINODE_API_URL

# Wait for Linode Instance to be provisioned
sleep 30

# SSH into the instance
ssh root@<INSTANCE_IP>

# Update the system and install necessary dependencies
apt update
apt upgrade -y
apt install -y curl gnupg2 apt-transport-https ca-certificates software-properties-common

# Install Docker
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu focal stable"
apt update
apt install -y docker-ce docker-ce-cli containerd.io

# Install Kubernetes
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
echo "deb https://apt.kubernetes.io/ kubernetes-xenial main" > /etc/apt/sources.list.d/kubernetes.list
apt update
apt install -y kubelet kubeadm kubectl
systemctl enable kubelet

# Install nginx
apt install -y nginx

# Install cert-manager
kubectl apply -f https://github.com/jetstack/cert-manager/releases/download/v1.5.3/cert-manager.yaml

# Install external-dns
kubectl apply -f https://github.com/kubernetes-sigs/external-dns/releases/download/v0.8.0/external-dns.yaml

# Install Portainer
kubectl apply -f https://raw.githubusercontent.com/portainer/k8s/master/deploy/manifests/portainer/portainer.yaml

# Exit the SSH session
exit
