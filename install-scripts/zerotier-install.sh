#!/usr/bin/env bash
set -Eeuo pipefail

log() { printf '[INFO] %s\n' "$*"; }
fatal() { printf '[ERROR] %s\n' "$*" >&2; exit 1; }

if [ "${EUID:-$(id -u)}" -ne 0 ]; then
    fatal "Run as root with sudo."
fi

if command -v zerotier-cli >/dev/null 2>&1; then
    log "ZeroTier is already installed."
    zerotier-cli info || true
    exit 0
fi

if command -v apt-get >/dev/null 2>&1; then
    . /etc/os-release
    CODENAME="${VERSION_CODENAME:-}"
    [ -n "$CODENAME" ] || fatal "Unable to detect Debian/Ubuntu codename from /etc/os-release."

    log "Installing ZeroTier via signed apt repository for ${ID:-debian} ${CODENAME}..."
    apt-get update
    DEBIAN_FRONTEND=noninteractive apt-get install -y curl gpg ca-certificates
    install -m 0755 -d /usr/share/keyrings
    curl -fsSL https://raw.githubusercontent.com/zerotier/ZeroTierOne/master/doc/contact%40zerotier.com.gpg \
        | gpg --dearmor -o /usr/share/keyrings/zerotier-archive-keyring.gpg
    chmod 0644 /usr/share/keyrings/zerotier-archive-keyring.gpg
    printf 'deb [signed-by=/usr/share/keyrings/zerotier-archive-keyring.gpg] https://download.zerotier.com/debian/%s %s main\n' \
        "${ID:-debian}" "$CODENAME" > /etc/apt/sources.list.d/zerotier.list
    apt-get update
    DEBIAN_FRONTEND=noninteractive apt-get install -y zerotier-one
elif command -v dnf >/dev/null 2>&1; then
    log "Installing ZeroTier with dnf..."
    dnf install -y zerotier-one
elif command -v yum >/dev/null 2>&1; then
    log "Installing ZeroTier with yum..."
    yum install -y zerotier-one
else
    fatal "No supported package manager found. Install ZeroTier manually from https://www.zerotier.com/download/."
fi

systemctl enable --now zerotier-one
zerotier-cli info || true
log "ZeroTier installation complete. Join a network with: sudo zerotier-cli join <network-id>"
