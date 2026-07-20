#!/usr/bin/env bash
set -Eeuo pipefail

log() { printf '[INFO] %s\n' "$*"; }
fatal() { printf '[ERROR] %s\n' "$*" >&2; exit 1; }

usage() {
    cat <<'USAGE'
Usage: ./git_setup.sh "Your Name" "you@example.com"

Configures Git identity and creates an SSH key for GitHub if one does not
already exist. The email address is required so the key comment is traceable to
the user instead of a hardcoded placeholder.
USAGE
}

GIT_NAME="${1:-}"
GIT_EMAIL="${2:-}"

if [ -z "$GIT_NAME" ] || [ -z "$GIT_EMAIL" ]; then
    usage
    fatal "Git name and email are required."
fi

if ! [[ "$GIT_EMAIL" =~ ^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$ ]]; then
    fatal "Invalid email address: $GIT_EMAIL"
fi

if command -v apt-get >/dev/null 2>&1 && ! command -v git >/dev/null 2>&1; then
    log "Git not found. Installing Git with apt-get..."
    sudo apt-get update
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y git openssh-client
elif ! command -v git >/dev/null 2>&1; then
    fatal "Git is not installed. Install git with your package manager, then rerun this script."
fi

log "Configuring Git identity..."
git config --global user.name "$GIT_NAME"
git config --global user.email "$GIT_EMAIL"

mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.ssh"

KEY_PATH="$HOME/.ssh/id_ed25519"
if [ ! -f "$KEY_PATH" ]; then
    log "Generating ed25519 SSH key for GitHub..."
    ssh-keygen -t ed25519 -C "$GIT_EMAIL" -f "$KEY_PATH" -N ""
else
    log "SSH key already exists at $KEY_PATH."
fi

if command -v ssh-agent >/dev/null 2>&1; then
    eval "$(ssh-agent -s)" >/dev/null
    ssh-add "$KEY_PATH" || true
fi

log "Copy the following SSH public key to GitHub:"
printf '\n'
cat "${KEY_PATH}.pub"
printf '\n\n'
cat <<'NEXT_STEPS'
GitHub SSH key steps:
1. Open GitHub → Settings → SSH and GPG keys.
2. Click "New SSH key".
3. Paste the public key above.
4. Test with: ssh -T git@github.com
NEXT_STEPS

log "GitHub setup is complete."
