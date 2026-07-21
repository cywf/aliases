# My on-the-go toolkit

This repo is meant to be a quick setup kit for terminal users and sys/net admin related work.
Feel free to fork or create a PR to contribute!

## Table of Contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Aliases](#aliases)
- [Portable Hermes USB](#portable-hermes-usb)
- [Installation Scripts](#installation-scripts)
- [Networking](#networking)
- [System Administration](#system-administration)
- [Development Tools](#development-tools)
- [Operational Standards](#operational-standards)
- [Hack The Box (HTB)](#hack-the-box-htb)
- [TAK (Team Awareness Kit)](#tak-team-awareness-kit)
- [StackScripts](#stackscripts)
- [Usage](#usage)
- [Examples](#examples)
- [Troubleshooting](#troubleshooting)
- [Contributing](#contributing)
- [License](#license)
- [Support](#support)

## Overview

This repository provides a comprehensive toolkit for system administrators, network engineers, and developers. It includes a collection of useful aliases, installation scripts, configuration examples, and automation tools designed to streamline common tasks and enhance productivity.

The toolkit is organized into several directories, each focusing on a specific domain:

- **Aliases**: Bash shortcuts for common commands
- **Portable Hermes USB**: locate, verify, bootstrap, and launch a USB-hosted Local-Hermes-Portable install
- **Installation Scripts**: Automated setup scripts for various tools
- **Networking**: Configuration examples and documentation
- **System Administration**: Tools for system management
- **Development Tools**: Resources for development environments
- **Operational Standards**: Script safety, dependency, platform, and testing guidance
- **HTB**: Pointer to the canonical HTB toolkit repository
- **TAK**: Pointer to the canonical TAK toolkit repository
- **StackScripts**: Linode automation scripts

## Prerequisites

Before using the tools in this repository, ensure you have:

### System Requirements

- **Operating System**: Linux-based system (Ubuntu/Debian recommended)
- **Permissions**: Appropriate permissions for system administration tasks (sudo access)
- **Disk Space**: Minimum 500MB free space for basic installations
- **Memory**: Minimum 2GB RAM (4GB+ recommended for development environments)
- **Processor**: Modern CPU with at least 2 cores

### Network Requirements

- **Internet Connectivity**: Required for downloading packages and tools
- **Firewall Access**: Outbound HTTPS (443) and HTTP (80) access
- **DNS Resolution**: Functional DNS for package repositories and services

### Software Dependencies

- **Package Manager**: APT (Ubuntu/Debian), YUM/DNF (CentOS/RHEL), or equivalent
- **Git**: Version control system for repository management
- **Python**: Python 3.6+ for Python-based tools
- **Bash**: Bourne Again SHell for script execution
- **Curl/Wget**: Command-line tools for downloading resources

### Optional Dependencies

- **Docker**: Container platform for containerized deployments
- **ZeroTier/Tailscale**: VPN solutions for secure networking
- **NGINX/Apache**: Web servers for hosting services
- **PostgreSQL**: Database system for data storage
- **TMUX**: Terminal multiplexer for session management

### User Knowledge

- **Basic Command-Line Skills**: Familiarity with Linux command-line operations
- **System Administration Concepts**: Understanding of networking, security, and system management
- **Security Best Practices**: Knowledge of secure system configuration
- **Troubleshooting Skills**: Ability to diagnose and resolve common system issues

### Hardware Considerations

- **Development Workloads**: 4GB+ RAM and 2+ CPU cores recommended
- **Server Deployments**: 8GB+ RAM and 4+ CPU cores recommended
- **Storage**: SSD storage recommended for better performance
- **Network Interface**: Gigabit Ethernet recommended for server applications

Individual scripts may have additional requirements which are documented in their respective directories.

## Aliases

The `.bash_aliases` file contains useful shortcuts for:

- **System Administration**: Update, upgrade, clean, reboot, shutdown commands
- **Networking**: IP configuration, ping, traceroute, DNS lookups, UFW firewall
- **Git**: Common git commands (status, add, commit, push, pull, clone)
- **Docker**: Docker and docker-compose shortcuts
- **TMUX**: Terminal multiplexer session management
- **ZeroTier**: VPN network management
- **Portable Hermes**: `sentinel`, `hermes-usb`, and `hermesusb` helpers for the preloaded Samsung BAR Plus drive
- **AI automation**: opt-in `automode` wrapper controlled by `AUTOMODE_CMD`

### Installing Aliases

```bash
# Copy the bash_aliases file to your home directory
cp bash_aliases ~/.bash_aliases

# Reload your bash configuration
source ~/.bashrc
```

## Portable Hermes USB

The portable Hermes workflow is built for the Samsung BAR Plus 128GB USB 3.1 flash drive that is already preloaded with Hermes configuration. The helper locates a mounted `Local-Hermes-Portable` checkout, verifies the portable launcher, prints the `SENTINEL ONLINE` / `Welcome Back Sir` banner, can optionally send a Telegram health report, and launches portable Hermes.

Primary commands after sourcing `bash_aliases`:

```bash
sentinel --verify-only      # locate and verify without launching
sentinel                    # locate, verify, and launch portable Hermes
hermes-usb --launcher       # run linux.sh/mac.sh instead of hermes/launch.sh
```

Useful overrides:

```bash
export ALIASES_REPO="$HOME/code/aliases"
HERMES_PORTABLE_ROOT="/media/$USER/BAR PLUS/Local-Hermes-Portable" sentinel --verify-only
HERMES_USB_TARGET="/media/$USER/BAR PLUS" hermes-usb --verify-only
HERMES_USB_NOTIFY=0 sentinel
```

Direct script usage:

```bash
install-scripts/hermes-portable-usb.sh --find-only
install-scripts/hermes-portable-usb.sh --verify-only
install-scripts/hermes-portable-usb.sh --no-bootstrap --verify-only
```

See [`install-scripts/README.md`](install-scripts/README.md#hermes-portable-usbsh) for full options, environment variables, and Telegram notification details.

## Installation Scripts

Located in `install-scripts/`, these scripts automate the installation and configuration of various tools:

### Container & Orchestration
- **docker-install.sh** - Install Docker CE
- **docker-deb-install.sh** - Install Docker from Debian packages
- **lazydocker-install.sh** - Install LazyDocker (terminal UI for Docker)
- **rancher-install.sh** - Install Rancher for Kubernetes management
- **helm-install.sh** - Install Helm package manager

### Networking & VPN
- **zerotier-install.sh** - Install ZeroTier VPN client
- **zerotier-conf.sh** - Configure ZeroTier networks
- **tailscale_manager.sh** - Manage Tailscale VPN

### Development Tools
- **git_setup.sh** - Configure Git with user details
- **setup_dev_environment.sh** - Set up a complete development environment
- **tmux-install.sh** - Install and configure TMUX

### Web & Security
- **nginx_setup.sh** - Install and configure Nginx
- **brave-browser.sh** - Install Brave browser
- **wazuh_wizard.sh** - Install and configure Wazuh security platform
- **teleport-install.sh** - Install Teleport access platform
- **wireshark-install.sh** - Install Wireshark network analyzer

### Gaming & AI
- **minecraft-install.sh** - Set up Minecraft server with Docker & ZeroTier
- **autogpt-install.sh** - Install AutoGPT
- **whisper.sh** - Install OpenAI Whisper
- **hermes-portable-usb.sh** - Locate, verify, bootstrap, and launch Local-Hermes-Portable from a USB drive

### Radio & SDR
- **rtl-sdr.sh** - Complete RTL-SDR setup with multiple SDR tools

### Other
- **usb-key-setup.sh** - Set up USB keys with various configurations

### Usage

```bash
cd install-scripts
chmod +x <script-name>.sh
./<script-name>.sh
```

## Networking

The `networking/` directory contains configuration examples and documentation:

- **example-advanced.nginx.conf** - Advanced Nginx configuration
- **ufw-rules.md** - UFW firewall rule examples
- **zerotier-default-ethernet.md** - ZeroTier ethernet bridge configuration

## System Administration

The `sysadmin/` directory contains system administration tools:

- **c-mgmt.py** - Python tool for container management
- **usb-helper.sh** - USB device management helper
- **disable-services.md** - Guide for disabling unnecessary services
- **linux-system-setup.sh** - Automated Linux system setup
- **wazuh-rules.md** - Wazuh security rules documentation

### Usage

```bash
cd sysadmin
chmod +x <script-name>.sh
./<script-name>.sh
```

## Development Tools

The `dev/` directory contains development-related resources:

- **terraform/** - Terraform configurations for infrastructure
  - **dev-server.md** - Development server setup guide

## Operational Standards

Use these documents before adding or changing operational scripts:

- [`docs/script-standards.md`](docs/script-standards.md) - shell/Python safety, error handling, remote installer, and rollback guidance
- [`docs/dependencies.md`](docs/dependencies.md) - dependency, package-manager, platform, and validation matrix

## Hack The Box (HTB)

HTB-specific tools have moved out of this general aliases repository.

- Canonical repo: <https://github.com/cywf/htb-helper>
- Local pointer: [`htb/README.md`](htb/README.md)

Use `cywf/htb-helper` for HTB setup workflows, Nmap/payload helpers, CTF scripts, documentation, issues, and pull requests.

## TAK (Team Awareness Kit)

TAK-specific setup assets have moved out of this general aliases repository.

- Canonical repo: <https://github.com/cywf/otg-tak>
- Local pointer: [`tak/README.md`](tak/README.md)

Use `cywf/otg-tak` for TAK server/client setup, Docker/Tailscale/ZeroTier notes, deployment automation, issues, and pull requests.

## StackScripts

The `stackscripts/` directory contains Linode StackScripts for automated server provisioning:

### Dev Server
- Pre-configured development server setup

### Web Server
- **provision.sh** - Web server provisioning script

## Usage Examples

### Basic System Setup

```bash
# Clone the repository
git clone https://github.com/cywf/aliases.git
cd aliases

# Install useful bash aliases
cp bash_aliases ~/.bash_aliases
source ~/.bashrc

# Update system packages
update

# Install Docker
cd install-scripts
chmod +x docker-install.sh
./docker-install.sh
```

### Network Configuration

```bash
# Configure UFW firewall
ufw enable
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp
ufw status verbose

# Install and configure ZeroTier
chmod +x zerotier-install.sh
./zerotier-install.sh
sudo zerotier-cli join NETWORK_ID

# Set up advanced NGINX configuration
sudo cp networking/example-advanced.nginx.conf /etc/nginx/sites-available/advanced
cd /etc/nginx/sites-enabled
sudo ln -s ../sites-available/advanced .
sudo nginx -t
sudo systemctl reload nginx
```

### Development Environment Setup

```bash
# Set up complete development environment
cd install-scripts
chmod +x setup_dev_environment.sh
./setup_dev_environment.sh

# Install Git and configure SSH keys
chmod +x git_setup.sh
./git_setup.sh "Your Name" "your.email@example.com"

# Install TMUX with enhanced configuration
cd ..
chmod +x tmux-install.sh
./tmux-install.sh
```

### Security Tools Installation

```bash
# Install Wazuh security platform
cd install-scripts
chmod +x wazuh_wizard.sh
./wazuh_wizard.sh

# Review the service-hardening guide
less sysadmin/disable-services.md

# Install Wireshark for network analysis
chmod +x wireshark-install.sh
./wireshark-install.sh
```

### Container Management

```bash
# Install Docker and Docker Compose
cd install-scripts
chmod +x docker-install.sh
./docker-install.sh

# Install LazyDocker for container management
chmod +x lazydocker-install.sh
./lazydocker-install.sh

# Use container management tools
python3 sysadmin/c-mgmt.py
```

### Penetration Testing Setup

HTB tools moved to their dedicated repository: <https://github.com/cywf/htb-helper>.

See [`htb/README.md`](htb/README.md) for the migration pointer and follow the canonical repo's current README for setup and usage.

### TAK Environment Setup

```bash
# TAK setup moved to its dedicated repository.
git clone https://github.com/cywf/otg-tak.git
cd otg-tak

# Follow that repository's README/INSTALL.md for deployment options.
```

See [`tak/README.md`](tak/README.md) for the migration pointer.

### Cloud Infrastructure Setup

```bash
# Set up development server on AWS with Terraform
cd dev/terraform
# Follow the instructions in dev-server.md
# Configure AWS CLI
aws configure
# Initialize Terraform
terraform init
# Apply configuration
terraform apply
```

### Automation and Scripting

```bash
# Use bash aliases for common tasks
update          # sudo apt-get update
upgrade         # sudo apt-get upgrade
gs              # git status
ga .            # git add .
gcm "Commit message"  # git commit -m "Commit message"
gp              # git push
ufws            # sudo ufw status
dps             # docker ps -a
```

### Server Provisioning

```bash
# Use Linode StackScripts for server provisioning
# Create a new Linode
# Select the appropriate StackScript
# Provide required parameters
# Deploy the Linode

# For web server deployment
cd stackscripts/webserver
# Review provision.sh
# Create StackScript in Linode dashboard
# Deploy with custom configuration
```

### Troubleshooting and Maintenance

```bash
# Check system status
sysinfo

# Check service status
sysctls docker

# Restart services
sysctlr nginx

# Clean up system
clean

# Check firewall status
ufws

# View system logs
journalctl -f
```

These examples demonstrate common usage patterns for the tools in this repository. Always review scripts before execution and ensure you understand the changes they will make to your system.

## Examples

### Basic Usage

```bash
# Update system packages
update

# Check system status
sys-status

# View network configuration
net-info
```

### Docker Installation

```bash
# Install Docker
./install-scripts/docker-install.sh

# Verify installation
docker --version
```

### Firewall Configuration

Review the tracked firewall examples before applying rules:

```bash
less networking/ufw-rules.md
sudo ufw status
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

4. **Portable Hermes USB Not Detected**
   - Confirm the Samsung BAR Plus drive is mounted and visible with `lsblk` or your file manager
   - Run `sentinel --find-only` or `install-scripts/hermes-portable-usb.sh --find-only`
   - Set `HERMES_PORTABLE_ROOT` to the exact `Local-Hermes-Portable` path, or `HERMES_USB_TARGET` to the USB mount root

### Getting Help

If you encounter issues not covered in this documentation:

1. Check the specific directory README for detailed troubleshooting
2. Open an issue on GitHub with detailed information
3. Include error messages and system information

## Contributing

Before opening a pull request, run the non-destructive validation baseline:

```bash
bash scripts/validate.sh
```

See [`TESTING.md`](TESTING.md) for CI and manual testing expectations.

Contributions are welcome! Please feel free to submit a Pull Request. When contributing:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## License

See [LICENSE](LICENSE) file for details.

## Support

For issues, questions, or contributions, please open an issue on GitHub.
