#!/usr/bin/env bash
set -Eeuo pipefail

log() { printf '[INFO] %s\n' "$*"; }
fatal() { printf '[ERROR] %s\n' "$*" >&2; exit 1; }

require_env() {
    local name="$1"
    if [ -z "${!name:-}" ]; then
        fatal "Missing required environment variable: $name"
    fi
}

require_env LINODE_ACCESS_TOKEN
require_env INSTANCE_ROOT_PASS
require_env INSTANCE_SSH_KEY

INSTANCE_TYPE="${INSTANCE_TYPE:-g6-nanode-1}"
REGION="${REGION:-us-west}"
INSTANCE_LABEL="${INSTANCE_LABEL:-aliases-webserver}"
INSTANCE_IMAGE="${INSTANCE_IMAGE:-linode/ubuntu22.04}"
LINODE_API_URL="https://api.linode.com/v4/linode/instances"
export INSTANCE_TYPE REGION INSTANCE_LABEL INSTANCE_IMAGE INSTANCE_ROOT_PASS INSTANCE_SSH_KEY

payload=$(python3 - <<'PY'
import json, os
print(json.dumps({
    "region": os.environ.get("REGION", "us-west"),
    "type": os.environ.get("INSTANCE_TYPE", "g6-nanode-1"),
    "image": os.environ.get("INSTANCE_IMAGE", "linode/ubuntu22.04"),
    "root_pass": os.environ["INSTANCE_ROOT_PASS"],
    "label": os.environ.get("INSTANCE_LABEL", "aliases-webserver"),
    "ssh_keys": [os.environ["INSTANCE_SSH_KEY"]],
    "backups_enabled": False,
    "private_ip": True,
}))
PY
)

log "Creating Linode instance ${INSTANCE_LABEL} in ${REGION}..."
response=$(curl -fsS \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer ${LINODE_ACCESS_TOKEN}" \
    -d "$payload" \
    -X POST \
    "$LINODE_API_URL")

INSTANCE_ID=$(printf '%s' "$response" | python3 -c '
import json, sys
print(json.load(sys.stdin)["id"])
')
log "Created Linode instance id: $INSTANCE_ID"

log "Waiting for instance networking information..."
for _ in $(seq 1 30); do
    instance=$(curl -fsS -H "Authorization: Bearer ${LINODE_ACCESS_TOKEN}" "$LINODE_API_URL/$INSTANCE_ID")
    INSTANCE_IP=$(printf '%s' "$instance" | python3 -c '
import json, sys
ips=json.load(sys.stdin).get("ipv4", [])
print(ips[0] if ips else "")
')
    if [ -n "$INSTANCE_IP" ]; then
        break
    fi
    sleep 10
done
[ -n "${INSTANCE_IP:-}" ] || fatal "Instance did not report an IPv4 address."
log "Instance IP: $INSTANCE_IP"

remote_script=$(cat <<'REMOTE'
set -Eeuo pipefail
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get upgrade -y
apt-get install -y curl gnupg ca-certificates software-properties-common apt-transport-https

install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg
. /etc/os-release
arch="$(dpkg --print-architecture)"
cat > /etc/apt/sources.list.d/docker.list <<EOF
deb [arch=${arch} signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu ${VERSION_CODENAME} stable
EOF

curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.30/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
cat > /etc/apt/sources.list.d/kubernetes.list <<EOF
deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.30/deb/ /
EOF

apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io kubelet kubeadm kubectl nginx
systemctl enable --now docker
systemctl enable kubelet
systemctl enable --now nginx
REMOTE
)

log "Running remote provisioning over SSH..."
ssh -o StrictHostKeyChecking=accept-new "root@${INSTANCE_IP}" "bash -s" <<<"$remote_script"

log "Provisioning complete for ${INSTANCE_IP}."
