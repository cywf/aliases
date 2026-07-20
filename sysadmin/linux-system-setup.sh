#!/usr/bin/env bash

set -Eeuo pipefail

log() { printf '[INFO] %s\n' "$*"; }
warn() { printf '[WARN] %s\n' "$*" >&2; }
fatal() { printf '[ERROR] %s\n' "$*" >&2; exit 1; }

# Ensure the script is run as root
if [ "${EUID}" -ne 0 ]; then
    fatal "This script must be run as root. Please use sudo or log in as root."
fi

if ! command -v apt-get >/dev/null 2>&1; then
    fatal "This setup script currently supports Debian/Ubuntu systems with apt-get only."
fi

TARGET_USER="${SUDO_USER:-${USER:-root}}"
if [ "$TARGET_USER" = "root" ]; then
    TARGET_HOME="/root"
else
    TARGET_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6)"
fi
TARGET_HOME="${TARGET_HOME:-/root}"

APT_UPDATED=0
SSH_PORT=22
FIREWALL_CHOICE="ufw"
ZEROTIER_NETWORK_ID=""
ZEROTIER_IP_ADDRESS=""

apt_update_once() {
    if [ "$APT_UPDATED" -eq 0 ]; then
        log "Updating apt package metadata..."
        apt-get update || fatal "apt-get update failed. Resolve apt/dpkg/network issues and retry."
        APT_UPDATED=1
    fi
}

install_packages_or_fail() {
    apt_update_once
    log "Installing packages: $*"
    DEBIAN_FRONTEND=noninteractive apt-get install -y "$@" || fatal "Package installation failed: $*"
}

require_command() {
    local cmd="$1"
    shift || true
    if ! command -v "$cmd" >/dev/null 2>&1; then
        install_packages_or_fail "$@"
    fi
    command -v "$cmd" >/dev/null 2>&1 || fatal "Required command still missing after install: $cmd"
}

# Prompt the user for input
get_user_input() {
    echo "Please provide the necessary configuration details:"

    read -r -p "Enter the SSH port you want to use (default is 22): " SSH_PORT
    SSH_PORT=${SSH_PORT:-22}
    if ! [[ "$SSH_PORT" =~ ^[0-9]+$ ]] || [ "$SSH_PORT" -lt 1 ] || [ "$SSH_PORT" -gt 65535 ]; then
        fatal "Invalid SSH port: $SSH_PORT"
    fi

    read -r -p "Enter the firewall you want to use (ufw/iptables/none, default is ufw): " FIREWALL_CHOICE
    FIREWALL_CHOICE=${FIREWALL_CHOICE:-ufw}

    read -r -p "Enter your Zerotier Network ID (leave blank to skip join): " ZEROTIER_NETWORK_ID
    if [ -n "$ZEROTIER_NETWORK_ID" ] && ! [[ "$ZEROTIER_NETWORK_ID" =~ ^[A-Za-z0-9]{16}$ ]]; then
        fatal "ZeroTier Network ID should be 16 hexadecimal/alphanumeric characters."
    fi

    read -r -p "Enter your Zerotier Network IP Address (if known, leave blank if not known): " ZEROTIER_IP_ADDRESS

    echo "Using SSH port: $SSH_PORT"
    echo "Using firewall: $FIREWALL_CHOICE"
    echo "Zerotier Network ID: ${ZEROTIER_NETWORK_ID:-Not joining now}"
    echo "Zerotier IP Address: ${ZEROTIER_IP_ADDRESS:-Not specified}"
}

# Check for essential tools and install them if missing
check_dependencies() {
    log "Checking and installing dependencies..."
    require_command curl curl
    require_command git git
    require_command gpg gnupg
    require_command install coreutils
    require_command lsb_release lsb-release
}

# Ensure sufficient disk space
check_disk_space() {
    log "Checking disk space..."
    local required_space_mb=500
    local available_space_mb
    available_space_mb=$(df -Pm / | awk 'NR==2 {print $4}')

    if [ "$available_space_mb" -lt "$required_space_mb" ]; then
        fatal "Not enough disk space. Need at least ${required_space_mb}MB free on /."
    fi
}

# Fix any dpkg configuration issues. Do not remove lock files from active apt processes.
fix_dpkg() {
    log "Checking for dpkg issues..."
    if fuser /var/lib/dpkg/lock >/dev/null 2>&1 || fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1; then
        fatal "Another apt/dpkg process is running. Wait for it to finish, then retry."
    fi

    dpkg --configure -a || fatal "dpkg --configure -a failed. Resolve dpkg state and retry."
}

ssh_service_name() {
    if systemctl list-unit-files ssh.service >/dev/null 2>&1; then
        printf 'ssh\n'
    elif systemctl list-unit-files sshd.service >/dev/null 2>&1; then
        printf 'sshd\n'
    else
        printf 'ssh\n'
    fi
}

has_authorized_keys() {
    local user_home="$1"
    [ -s "$user_home/.ssh/authorized_keys" ] && return 0
    [ -s "/root/.ssh/authorized_keys" ] && return 0
    return 1
}

set_sshd_config_value() {
    local key="$1" value="$2" file="$3" tmp
    tmp="$(mktemp)"
    awk -v key="$key" -v value="$value" '
        BEGIN { written=0 }
        $1 == key || $1 == "#" key { if (!written) { print key " " value; written=1 } ; next }
        { print }
        END { if (!written) print key " " value }
    ' "$file" > "$tmp"
    cat "$tmp" > "$file"
    rm -f "$tmp"
}

# Lock down SSH without risking lockout from missing authorized_keys.
secure_ssh() {
    log "Securing SSH..."
    local ssh_config_file="/etc/ssh/sshd_config"
    local service

    [ -f "$ssh_config_file" ] || fatal "SSH config not found: $ssh_config_file"
    cp "$ssh_config_file" "${ssh_config_file}.bak.$(date +%Y%m%d%H%M%S)"

    set_sshd_config_value Port "$SSH_PORT" "$ssh_config_file"
    set_sshd_config_value PermitRootLogin no "$ssh_config_file"

    if has_authorized_keys "$TARGET_HOME"; then
        set_sshd_config_value PasswordAuthentication no "$ssh_config_file"
    else
        warn "No authorized_keys found for $TARGET_USER or root; leaving PasswordAuthentication enabled to avoid lockout."
        set_sshd_config_value PasswordAuthentication yes "$ssh_config_file"
    fi

    sshd -t -f "$ssh_config_file" || fatal "sshd_config validation failed; backup retained beside $ssh_config_file."
    service="$(ssh_service_name)"
    systemctl restart "$service" || fatal "Failed to restart SSH service: $service"
}

# Update and upgrade the server
update_upgrade() {
    log "Updating and upgrading server..."
    apt_update_once
    DEBIAN_FRONTEND=noninteractive apt-get upgrade -y || fatal "apt-get upgrade failed."
}

# Configure the firewall based on user choice
configure_firewall() {
    log "Configuring firewall..."
    case "$FIREWALL_CHOICE" in
        ufw)
            install_packages_or_fail ufw
            ufw allow "$SSH_PORT/tcp" || fatal "Failed to allow SSH port through UFW."
            ufw --force enable || fatal "Failed to enable UFW."
            ;;
        iptables)
            install_packages_or_fail iptables iptables-persistent
            iptables -C INPUT -p tcp --dport "$SSH_PORT" -j ACCEPT 2>/dev/null || \
                iptables -A INPUT -p tcp --dport "$SSH_PORT" -j ACCEPT || fatal "Failed to add iptables SSH rule."
            netfilter-persistent save || fatal "Failed to save iptables rules."
            ;;
        none|skip)
            warn "Skipping firewall configuration by request."
            ;;
        *)
            fatal "Firewall choice not recognized: $FIREWALL_CHOICE"
            ;;
    esac
}

install_docker_official_repo() {
    log "Installing Docker from the official Docker apt repository..."
    install_packages_or_fail ca-certificates curl gnupg
    install -m 0755 -d /etc/apt/keyrings
    local codename arch distro_id docker_distro
    codename="$(. /etc/os-release && printf '%s' "${VERSION_CODENAME:-}")"
    distro_id="$(. /etc/os-release && printf '%s' "${ID:-}")"
    arch="$(dpkg --print-architecture)"
    [ -n "$codename" ] || fatal "Could not detect Debian/Ubuntu codename for Docker repository."
    case "$distro_id" in
        ubuntu|debian) docker_distro="$distro_id" ;;
        *) fatal "Docker official repository setup supports Debian/Ubuntu only; detected: ${distro_id:-unknown}" ;;
    esac

    rm -f /etc/apt/keyrings/docker.gpg
    curl -fsSL "https://download.docker.com/linux/${docker_distro}/gpg" | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg

    printf 'deb [arch=%s signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/%s %s stable\n' "$arch" "$docker_distro" "$codename" \
        > /etc/apt/sources.list.d/docker.list
    APT_UPDATED=0
    install_packages_or_fail docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
}

install_zerotier_official_repo() {
    log "Installing ZeroTier from the official apt repository without curl|bash..."
    install_packages_or_fail ca-certificates curl gnupg
    install -m 0755 -d /etc/apt/keyrings
    rm -f /etc/apt/keyrings/zerotier.gpg
    curl -fsSL https://raw.githubusercontent.com/zerotier/ZeroTierOne/master/doc/contact%40zerotier.com.gpg | \
        gpg --dearmor -o /etc/apt/keyrings/zerotier.gpg
    chmod a+r /etc/apt/keyrings/zerotier.gpg

    local codename
    codename="$(. /etc/os-release && printf '%s' "${VERSION_CODENAME:-}")"
    [ -n "$codename" ] || fatal "Could not detect Debian/Ubuntu codename for ZeroTier repository."
    printf 'deb [signed-by=/etc/apt/keyrings/zerotier.gpg] https://download.zerotier.com/debian/%s %s main\n' "$codename" "$codename" \
        > /etc/apt/sources.list.d/zerotier.list
    APT_UPDATED=0
    install_packages_or_fail zerotier-one
}

# Install ZeroTier, Docker, TMUX, and Git
install_packages() {
    log "Installing ZeroTier, Docker, TMUX, and Git..."
    install_zerotier_official_repo
    install_docker_official_repo
    install_packages_or_fail tmux git lynis libpam-pwquality

    if [ -n "$ZEROTIER_NETWORK_ID" ]; then
        log "Joining Zerotier Network..."
        zerotier-cli join "$ZEROTIER_NETWORK_ID" || fatal "Failed to join ZeroTier network $ZEROTIER_NETWORK_ID."
        echo "Please authorize this device on the Zerotier Central web interface."
        if [ -n "$ZEROTIER_IP_ADDRESS" ]; then
            echo "After authorizing the device, assign the IP address $ZEROTIER_IP_ADDRESS via the Zerotier Central web interface."
        fi
    else
        warn "ZeroTier Network ID not provided; installed ZeroTier but skipped network join."
    fi
}

# Clone/update the aliases repository and copy bash_aliases for the invoking user.
setup_aliases() {
    log "Setting up aliases for $TARGET_USER..."
    local repo_dir="$TARGET_HOME/aliases"
    local aliases_file="$TARGET_HOME/.bash_aliases"

    if [ -d "$repo_dir/.git" ]; then
        git -C "$repo_dir" pull --ff-only || fatal "Failed to update existing aliases repo at $repo_dir."
    elif [ -e "$repo_dir" ]; then
        fatal "$repo_dir exists but is not a git repository. Move it aside or set up aliases manually."
    else
        git clone https://github.com/cywf/aliases.git "$repo_dir" || fatal "Failed to clone aliases repository."
    fi

    cp "$repo_dir/bash_aliases" "$aliases_file" || fatal "Failed to copy bash aliases to $aliases_file."
    chown -R "$TARGET_USER:$TARGET_USER" "$repo_dir" "$aliases_file" 2>/dev/null || true
    echo "Aliases installed to $aliases_file. Run 'source ~/.bashrc' in your user shell or open a new terminal."
}

# Install Lynis and perform a system scan
run_lynis_scan() {
    log "Running Lynis security audit..."
    lynis audit system --quiet --no-colors > /tmp/lynis.log || warn "Lynis completed with findings; review /tmp/lynis.log."

    local critical_warnings
    critical_warnings=$(grep -E '^\s*\[WARNING\]+' /tmp/lynis.log | grep -Ei 'high|critical' || true)

    if [ -n "$critical_warnings" ]; then
        echo "Critical vulnerabilities found:"
        echo "$critical_warnings"

        read -r -p "Would you like to attempt to remediate these issues? (yes/no): " REMEDIATE_CHOICE
        if [ "$REMEDIATE_CHOICE" = "yes" ]; then
            remediate_lynis_issues
        else
            echo "Skipping remediation."
        fi
    else
        echo "No critical vulnerabilities found."
    fi
}

# Function to attempt to remediate issues found by Lynis
remediate_lynis_issues() {
    log "Attempting to remediate selected Lynis issues..."
    local ssh_config_file="/etc/ssh/sshd_config"

    if grep -q "^PermitRootLogin yes" "$ssh_config_file"; then
        log "Disabling root login over SSH..."
        set_sshd_config_value PermitRootLogin no "$ssh_config_file"
        sshd -t -f "$ssh_config_file" || fatal "sshd_config validation failed during Lynis remediation."
        systemctl restart "$(ssh_service_name)" || fatal "Failed to restart SSH after Lynis remediation."
    fi

    if [ -f /etc/security/pwquality.conf ]; then
        log "Setting password quality requirements with pam_pwquality..."
        sed -i.bak \
            -e 's/^#\?\s*minlen\s*=.*/minlen = 12/' \
            -e 's/^#\?\s*dcredit\s*=.*/dcredit = -1/' \
            -e 's/^#\?\s*ucredit\s*=.*/ucredit = -1/' \
            -e 's/^#\?\s*lcredit\s*=.*/lcredit = -1/' \
            -e 's/^#\?\s*ocredit\s*=.*/ocredit = -1/' \
            /etc/security/pwquality.conf
        grep -q '^password.*pam_pwquality.so' /etc/pam.d/common-password || \
            sed -i '1ipassword requisite pam_pwquality.so retry=3' /etc/pam.d/common-password
    else
        warn "pam_pwquality configuration not found; skipping password quality remediation."
    fi

    echo "Remediation complete."
}

main() {
    get_user_input
    check_disk_space
    check_dependencies
    fix_dpkg
    secure_ssh
    update_upgrade
    configure_firewall
    install_packages
    run_lynis_scan
    setup_aliases
    echo "Server setup complete."
}

main "$@"
