#!/usr/bin/env bash
#
############################################
# Dev: KP
# Date: May 17, 2025
# Version: v1.0.3
############################################
#
set -euo pipefail
IFS=$'\n\t'

############################################
# CONFIGURATION
############################################
VERSION="0.21.0"             # LazyDocker version (no leading “v”)
TAG="v${VERSION}"            # GitHub release tag
BINARY="lazydocker"          # Executable name

############################################
# 1) Detect system architecture
############################################
ARCH=$(uname -m)
case "${ARCH}" in
  x86_64|amd64) TARGET="x86_64" ;;
  aarch64|arm64) TARGET="arm64" ;;
  armv7l|armv7) TARGET="armv7" ;;
  *)
    echo "Unsupported architecture: ${ARCH}"
    exit 1
    ;;
esac

# Build the tarball name & download URL
TARBALL="${BINARY}_${VERSION}_Linux_${TARGET}.tar.gz"
DOWNLOAD_URL="https://github.com/jesseduffield/${BINARY}/releases/download/${TAG}/${TARBALL}"

############################################
# 2) Install prerequisites (curl, tar)
############################################
install_deps() {
  echo "-> Installing curl and tar"
  if command -v apt-get &>/dev/null; then
    sudo apt-get update
    sudo apt-get install -y curl tar
  elif command -v apt &>/dev/null; then
    sudo apt update
    sudo apt install -y curl tar
  elif command -v dnf &>/dev/null; then
    sudo dnf install -y curl tar
  elif command -v yum &>/dev/null; then
    sudo yum install -y curl tar
  else
    echo "No supported package manager found. Please install curl & tar manually."
    exit 1
  fi
}
install_deps

############################################
# 3) Prepare a temporary workspace
############################################
TMPDIR=$(mktemp -d)
trap 'rm -rf "${TMPDIR}"' EXIT   # Cleanup temp dir on script exit

############################################
# 4) Download the LazyDocker tarball
############################################
echo "-> Downloading ${BINARY} ${VERSION} for ${TARGET}"
curl -fsSL "${DOWNLOAD_URL}" -o "${TMPDIR}/${TARBALL}"

############################################
# 5) Extract the archive
############################################
echo "-> Extracting ${TARBALL}"
tar -xzf "${TMPDIR}/${TARBALL}" -C "${TMPDIR}"

############################################
# 6) Move binary into place
############################################
DEST="/usr/local/bin/${BINARY}"
# Use sudo only if needed
if [ ! -w "$(dirname "${DEST}")" ]; then
  SUDO="sudo"
else
  SUDO=""
fi

echo "-> Installing binary to ${DEST}"
${SUDO} mv "${TMPDIR}/${BINARY}" "${DEST}"
${SUDO} chmod +x "${DEST}"

############################################
# 7) Verify installation
############################################
if command -v "${BINARY}" &>/dev/null; then
  echo "✅ ${BINARY} ${VERSION} installed successfully!"
else
  echo "❌ Installation failed: ${BINARY} not found in PATH."
  exit 1
fi

############################################
# 8) Add alias to .bash_aliases and source ~/.bashrc
############################################
ALIAS_FILE="${HOME}/.bash_aliases"
ALIAS_CMD="alias ldoc='lazydocker'"

# Add alias only if it doesn't already exist
if ! grep -Fxq "${ALIAS_CMD}" "${ALIAS_FILE}" 2>/dev/null; then
  echo "${ALIAS_CMD}" >> "${ALIAS_FILE}"
  echo "-> Added alias: ldoc -> lazydocker to ${ALIAS_FILE}"
else
  echo "-> Alias 'ldoc' already exists in ${ALIAS_FILE}"
fi

# Source .bashrc to update the shell environment
if [ -f "${HOME}/.bashrc" ]; then
  echo "-> Sourcing ~/.bashrc"
  # shellcheck disable=SC1090
  source "${HOME}/.bashrc"
else
  echo "-> ~/.bashrc not found. Please reload your shell manually."
fi
