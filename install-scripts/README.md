# Installation Scripts

This directory contains automated scripts for installing and configuring various tools and services. Each script is designed to work on Ubuntu/Debian-based systems and handles the complete installation process including dependencies, configuration, and post-installation setup.

## Table of Contents

- [Container & Orchestration](#container--orchestration)
- [Networking & VPN](#networking--vpn)
- [Development Tools](#development-tools)
- [Web & Security](#web--security)
- [Gaming & AI](#gaming--ai)
- [Radio & SDR](#radio--sdr)
- [Other](#other)

## Container & Orchestration

### docker-install.sh

Installs Docker Community Edition with all necessary components including Docker Compose plugin.

**Requirements:**

- Ubuntu/Debian-based system
- Internet connectivity
- sudo privileges

**Usage:**

```bash
chmod +x docker-install.sh
./docker-install.sh
```

**Features:**

- Removes old Docker versions
- Installs latest Docker CE
- Configures Docker to start on boot
- Adds user to docker group
- Sets up proper permissions

### docker-deb-install.sh

Installs Docker from official Debian packages.

**Requirements:**

- Debian-based system
- Internet connectivity
- sudo privileges

**Usage:**

```bash
chmod +x docker-deb-install.sh
./docker-deb-install.sh
```

### lazydocker-install.sh

Installs LazyDocker, a terminal UI for Docker and Docker Compose.

**Requirements:**

- Docker already installed
- Internet connectivity

**Usage:**

```bash
chmod +x lazydocker-install.sh
./lazydocker-install.sh
```

### rancher-install.sh

Installs Rancher for Kubernetes management.

**Requirements:**

- Docker already installed
- Internet connectivity
- At least 4GB RAM

**Usage:**

```bash
chmod +x rancher-install.sh
./rancher-install.sh
```

### helm-install.sh

Installs Helm package manager for Kubernetes.

**Requirements:**

- Kubernetes cluster access
- Internet connectivity

**Usage:**

```bash
chmod +x helm-install.sh
./helm-install.sh
```

## Networking & VPN

### zerotier-install.sh

Installs the ZeroTier VPN client on Ubuntu/Debian systems using the upstream ZeroTier installer.

**Requirements:**

- Ubuntu/Debian-based system
- Internet connectivity
- sudo privileges
- Review of the upstream installer before execution if used on sensitive hosts

**Usage:**

```bash
chmod +x zerotier-install.sh
./zerotier-install.sh
```

**Security notes:**

- The script delegates to ZeroTier's official install endpoint.
- Run it only from a trusted network and review the script before production use:

```bash
curl -fsSL https://install.zerotier.com | less
```

- Join networks explicitly after installation with `zerotier-cli join <network-id>`.


### zerotier-conf.sh

Configures ZeroTier networks.

**Requirements:**

- ZeroTier already installed
- Network ID

**Usage:**

```bash
chmod +x zerotier-conf.sh
./zerotier-conf.sh <network-id>
```

### tailscale_manager.sh

Manages Tailscale VPN connections.

**Requirements:**

- Tailscale already installed
- Tailscale account

**Usage:**

```bash
chmod +x tailscale_manager.sh
./tailscale_manager.sh [up|down|status]
```

## Development Tools

### git_setup.sh

Configures Git with user details.

**Requirements:**

- Git already installed
- User information

**Usage:**

```bash
chmod +x git_setup.sh
./git_setup.sh "Your Name" "your.email@example.com"
```

### setup_dev_environment.sh

Sets up a complete development environment.

**Requirements:**

- Ubuntu/Debian-based system
- Internet connectivity
- sudo privileges

**Usage:**

```bash
chmod +x setup_dev_environment.sh
./setup_dev_environment.sh
```

### tmux-install.sh

Installs and configures TMUX terminal multiplexer.

**Requirements:**

- Ubuntu/Debian-based system
- Internet connectivity
- sudo privileges

**Usage:**

```bash
chmod +x tmux-install.sh
./tmux-install.sh
```

## Web & Security

### nginx_setup.sh

Installs and configures Nginx web server.

**Requirements:**

- Ubuntu/Debian-based system
- Internet connectivity
- sudo privileges

**Usage:**

```bash
chmod +x nginx_setup.sh
./nginx_setup.sh
```

### brave-browser.sh

Installs Brave browser.

**Requirements:**

- Ubuntu/Debian-based system
- Internet connectivity
- sudo privileges

**Usage:**

```bash
chmod +x brave-browser.sh
./brave-browser.sh
```

### wazuh_wizard.sh

Installs and configures Wazuh security platform.

**Requirements:**

- Ubuntu/Debian-based system
- Internet connectivity
- sudo privileges
- At least 4GB RAM

**Usage:**

```bash
chmod +x wazuh_wizard.sh
./wazuh_wizard.sh
```

### teleport-install.sh

Installs Teleport access platform.

**Requirements:**

- Ubuntu/Debian-based system
- Internet connectivity
- sudo privileges

**Usage:**

```bash
chmod +x teleport-install.sh
./teleport-install.sh
```

### wireshark-install.sh

Installs Wireshark network analyzer.

**Requirements:**

- Ubuntu/Debian-based system
- Internet connectivity
- sudo privileges

**Usage:**

```bash
chmod +x wireshark-install.sh
./wireshark-install.sh
```

## Gaming & AI

### minecraft-install.sh

Sets up Minecraft server with Docker & ZeroTier.

**Requirements:**

- Docker already installed
- ZeroTier already installed
- Internet connectivity

**Usage:**

```bash
chmod +x minecraft-install.sh
./minecraft-install.sh
```

### autogpt-install.sh

Installs AutoGPT.

**Requirements:**

- Python 3.8+
- Internet connectivity

**Usage:**

```bash
chmod +x autogpt-install.sh
./autogpt-install.sh
```

### whisper.sh

Installs OpenAI Whisper.

**Requirements:**

- Python 3.8+
- Internet connectivity
- At least 4GB RAM

**Usage:**

```bash
chmod +x whisper.sh
./whisper.sh
```

### hermes-portable-usb.sh

Locates a mounted Local-Hermes-Portable USB drive, verifies the portable Hermes launcher, prints the `SENTINEL ONLINE` / `Welcome Back Sir` terminal banner, optionally sends a Telegram health report, and starts portable Hermes. If the USB is mounted but `Local-Hermes-Portable` is not present, the script can bootstrap it from `https://github.com/techjarves/Local-Hermes-Portable`.

**Requirements:**

- Linux or macOS
- Mounted USB drive, ideally the preloaded Samsung BAR Plus drive
- `git`, or `curl` + `tar`, only if bootstrapping `Local-Hermes-Portable` onto the USB is needed
- `curl` only if Telegram notification is desired
- Telegram bot token/chat ID via environment variables or `.telegram.env` on the USB

**Usage:**

```bash
chmod +x hermes-portable-usb.sh
./hermes-portable-usb.sh --verify-only
./hermes-portable-usb.sh
./hermes-portable-usb.sh --launcher   # run linux.sh/mac.sh instead of hermes/launch.sh
```

After sourcing `bash_aliases`, the expected shortcuts are:

```bash
sentinel
hermes-usb
hermesusb   # legacy compatibility
```

Useful overrides:

```bash
HERMES_PORTABLE_ROOT=/Volumes/BAR\ PLUS/Local-Hermes-Portable sentinel --verify-only
HERMES_USB_TARGET=/Volumes/BAR\ PLUS hermes-usb --verify-only
HERMES_USB_NOTIFY=0 sentinel
```

## Radio & SDR

### rtl-sdr.sh

Complete RTL-SDR setup with multiple SDR tools.

**Requirements:**

- Ubuntu/Debian-based system
- RTL-SDR hardware
- Internet connectivity
- sudo privileges

**Usage:**

```bash
chmod +x rtl-sdr.sh
./rtl-sdr.sh
```

## Other

### usb-key-setup.sh

Sets up USB keys with various configurations.

**Requirements:**

- USB key inserted
- sudo privileges

**Usage:**

```bash
chmod +x usb-key-setup.sh
./usb-key-setup.sh
```

## Troubleshooting

### Common Issues

1. **Permission Denied Errors**
   - Ensure you have appropriate permissions
   - Run scripts with `sudo` if required

2. **Package Installation Failures**
   - Check internet connectivity
   - Update package lists with `sudo apt update`

3. **Script Execution Issues**
   - Verify script permissions with `chmod +x`
   - Check script syntax with `bash -n`

### Getting Help

If you encounter issues not covered in this documentation:

1. Check the specific script header for detailed information
2. Open an issue on GitHub with detailed information
3. Include error messages and system information
