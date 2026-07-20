# Dependency and Platform Matrix

This matrix records the expected package managers, major dependencies, and validation style for the operational scripts in this repository.

## Platform support policy

- Scripts that are Debian/Ubuntu-only must say so in their script header and README entry.
- Cross-platform scripts should detect the available package manager before installing dependencies.
- Package names differ across distributions; do not assume an apt package name exists in dnf/yum/pacman.
- Version-sensitive tools should use either distro packages or a documented pinned version.

## Common package-manager commands

| Package manager | Update metadata | Install packages |
| --- | --- | --- |
| apt | `apt-get update` | `DEBIAN_FRONTEND=noninteractive apt-get install -y <packages>` |
| dnf | `dnf makecache` | `dnf install -y <packages>` |
| yum | `yum makecache` | `yum install -y <packages>` |
| pacman | `pacman -Sy` | `pacman -S --noconfirm <packages>` |
| brew | `brew update` | `brew install <packages>` |

## Script categories

| Area | Examples | Expected dependencies | Notes |
| --- | --- | --- | --- |
| Docker/container tools | `docker-install.sh`, `docker-deb-install.sh`, `lazydocker-install.sh`, `rancher-install.sh` | curl, gpg/ca-certificates, Docker packages | Use signed package repositories; avoid deprecated `apt-key`. |
| VPN/networking | `tailscale_manager.sh`, `zerotier-install.sh`, `zerotier-conf.sh` | curl, gpg, service manager, iptables where needed | Joining networks should require explicit user input. |
| USB/security helpers | `usb-helper.sh`, `usb-key-setup.sh` | lsblk, curl, dd, cryptsetup/FIDO packages depending on option | Do not run destructive disk operations without listing and confirming the exact removable target. |
| Sysadmin setup | `linux-system-setup.sh`, `wazuh_wizard.sh` | package manager, systemd, SSH, Docker/Compose for Wazuh | Must validate service names and config before restart where possible. |
| Cloud/StackScripts | `stackscripts/webserver/provision.sh` | cloud credentials, curl, SSH, package manager | Credentials must come from environment variables or secret stores, never committed placeholders. |
| Python utilities | `sysadmin/c-mgmt.py` | Python 3, optional Docker CLI | Self-tests must avoid host-mutating Docker commands. |

## Version pinning guidance

Pin or document versions when:

- upstream install output can change without repository changes
- a generated config depends on a major version
- a package repository uses versioned paths, such as Kubernetes repos
- the script provisions cloud or security infrastructure

Use distro packages for stable baseline tools where practical. For downloaded artifacts, prefer a release URL plus checksum/signature verification.

## Test strategy

- Syntax-only checks are safe for CI.
- Behavior tests for package installs, disk writes, firewall changes, Docker removals, and cloud provisioning must run in disposable hosts.
- PRs that change side-effecting scripts should include manual test evidence or state that runtime validation was intentionally not executed because it would mutate the host.
