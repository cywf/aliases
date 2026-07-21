# Script Standards

These standards define the baseline for shell/Python scripts in this repository. They are intended to keep operational helpers predictable, reviewable, and safe on real systems.

## Shell baseline

Every shell script should:

- start with an explicit shebang, preferably `#!/usr/bin/env bash` for Bash scripts
- use `set -Eeuo pipefail` unless the script has a documented compatibility reason not to
- quote variable expansions unless word-splitting is intentional
- check directory changes: `cd "$target" || exit 1` or return through the script's error handler
- check critical commands directly with `if ! command; then ...; fi` when custom recovery or rollback is required
- use arrays for package names and command arguments where possible
- print actionable errors that include the failed operation and target
- avoid changing firewall, package, disk, service, or cloud state without a prompt or documented noninteractive flag

## Critical command handling

Critical commands include operations that install packages, download artifacts, write disks, edit system config, change services, alter firewall rules, create cloud resources, or delete data.

Preferred patterns:

```bash
if ! apt-get update; then
  echo "ERROR: apt-get update failed" >&2
  exit 1
fi

if ! cd "$install_dir"; then
  echo "ERROR: failed to enter $install_dir" >&2
  return 1
fi
```

Avoid relying only on a later command to reveal earlier failure. If a command changes persistent system state, record enough context to roll back or explain manual rollback.

## Package-manager detection

Do not assume Debian/Ubuntu unless the script is explicitly documented as Debian/Ubuntu-only. Use a helper-style detection pattern:

```bash
if command -v apt-get >/dev/null 2>&1; then
  PM=apt
elif command -v dnf >/dev/null 2>&1; then
  PM=dnf
elif command -v yum >/dev/null 2>&1; then
  PM=yum
elif command -v pacman >/dev/null 2>&1; then
  PM=pacman
else
  echo "ERROR: no supported package manager found" >&2
  exit 1
fi
```

When only one package manager is supported, say so in the script header and README entry.

## Repository signing keys

Do not use `apt-key`; it is deprecated. Use a dedicated keyring and `signed-by=` source entry:

```bash
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://example.invalid/repo.gpg | gpg --dearmor -o /etc/apt/keyrings/example.gpg
chmod 0644 /etc/apt/keyrings/example.gpg
echo 'deb [signed-by=/etc/apt/keyrings/example.gpg] https://example.invalid stable main' \
  > /etc/apt/sources.list.d/example.list
```

## Remote installers

Avoid `curl URL | bash` and `curl URL | sh`. Prefer signed package repositories, pinned release artifacts, checksums, or explicit manual review before execution.

If an upstream installer is unavoidable, the script must:

1. download it to a temporary file
2. show the source URL
3. verify checksum or signature when available
4. require an explicit confirmation before execution

## Documentation header template

Every operational script should include a short header near the top:

```bash
# Purpose: what this script does.
# Supported platforms: Ubuntu 22.04/24.04, Debian 12, etc.
# Requires: sudo, curl, gpg, docker, etc.
# Side effects: packages/services/files/firewall/cloud resources changed.
# Rollback: how to undo or where backup files are written.
```

## Validation

Run the non-destructive repository validation before opening a PR:

```bash
bash scripts/validate.sh
```

This catches syntax regressions without executing destructive or host-mutating workflows.
