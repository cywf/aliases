# =============================================================================
# BASH ALIASES - Enhanced Command Shortcuts
# =============================================================================

# -----------------------------------------------------------------------------
# SYSTEM ADMINISTRATION - System management and maintenance commands
# -----------------------------------------------------------------------------

# Bash configuration management
alias ebash="nano ~/.bash_aliases"                    # Edit bash aliases file
alias sbash="source ~/.bashrc"                        # Reload bash configuration
alias srcbash="source ~/.bashrc"                      # Source bashrc file
alias srczsh="source ~/.zshrc"                        # Source zshrc file
alias srcprofile="source ~/.profile"                  # Source profile file
alias srcaliases="source ~/.aliases"                  # Source aliases file
alias editbash="nano ~/.bashrc"                       # Edit bashrc file
alias editzsh="nano ~/.zshrc"                         # Edit zshrc file
alias editprofile="nano ~/.profile"                   # Edit profile file
alias editaliases="nano ~/.bash_aliases"              # Edit aliases file

# System operations
alias cl="clear"                                      # Clear terminal screen
alias update="sudo apt-get update"                    # Update package lists
alias upgrade="sudo apt-get upgrade"                  # Upgrade installed packages
alias goget="sudo apt-get install"                    # Install packages
alias clean="sudo apt-get clean; sudo apt-get autoclean; sudo apt-get autoremove"  # Clean package cache
alias reboot="sudo reboot"                            # Reboot system
alias shutdown="sudo shutdown -h now"                 # Shutdown system immediately
alias off="sudo shutdown -h now"                      # Shutdown system (alternative)
alias sysinfo="sudo lshw -short"                      # Display hardware information
alias sysctls="sudo systemctl status"                 # View systemd service status
alias sysctlr="sudo systemctl restart"                # Restart systemd service
alias q="quit"                                        # Quit command
alias e="exit"                                        # Exit current session

# File editing with elevated privileges
alias snano="sudo nano"                               # Edit files with nano as root
alias svi="sudo vi"                                   # Edit files with vi as root

# -----------------------------------------------------------------------------
# NETWORKING - Network configuration and diagnostics
# -----------------------------------------------------------------------------

# IP address information
alias ip="ifconfig"                                   # Display network interface information
alias ip4="ifconfig | grep 'inet ' | grep -v 'inet6 '"  # Show IPv4 addresses only
alias ip6="ifconfig | grep 'inet6 '"                  # Show IPv6 addresses only
alias ip4only="ifconfig | grep 'inet ' | grep -v 'inet6 ' | awk '{print $2}'"  # Show IPv4 addresses only (values)
alias ip6only="ifconfig | grep 'inet6 ' | awk '{print $2}'"  # Show IPv6 addresses only (values)
alias ip4public="curl -s http://ipecho.net/plain; echo"  # Show public IPv4 address
alias ip6public="curl -s http://ipv6.icanhazip.com; echo"  # Show public IPv6 address
alias ippublic="curl -s http://ipecho.net/plain; echo"  # Show public IP address
alias iplocal="ip addr show | grep 'inet ' | grep -v 'inet6 ' | grep -v '127.0.0.1'"  # Show local IP addresses

# Network diagnostics
alias p1="ping 1.1.1.1"                               # Ping Cloudflare DNS
alias tr1="traceroute 1.1.1.1"                        # Traceroute to Cloudflare DNS
alias dg="dig google.com"                             # DNS lookup for Google
alias ns="nslookup google.com"                        # Name server lookup for Google

# Firewall management
alias ufw="sudo ufw"                                  # Uncomplicated Firewall command
alias ufws="sudo ufw status"                          # Show firewall status
alias ufwa="sudo ufw allow"                           # Allow traffic through firewall
alias ufwd="sudo ufw deny"                            # Deny traffic through firewall

# -----------------------------------------------------------------------------
# GIT - Version control system shortcuts
# -----------------------------------------------------------------------------

alias g="git"                                         # Git command shortcut
alias gs="git status"                                 # Show git repository status
alias ga="git add"                                    # Add files to git staging
alias gc="git commit"                                 # Commit staged changes
alias gcl="git clone"                                 # Clone a repository
alias gcm="git commit -m"                             # Commit with message
alias gca="git commit -a"                             # Commit all tracked files
alias gcam="git commit -am"                           # Commit all with message
alias gp="git push"                                   # Push changes to remote
alias gpl="git pull"                                  # Pull changes from remote
alias gplm="git pull origin master"                   # Pull from origin master
alias gps="git push origin main"                      # Push to origin main
alias gpsm="git push origin master"                   # Push to origin master

# -----------------------------------------------------------------------------
# DOCKER - Container management shortcuts
# -----------------------------------------------------------------------------

alias d="docker"                                      # Docker command shortcut
alias dc="docker-compose"                             # Docker Compose command
alias dps="docker ps -a"                              # List all docker containers
alias ds="docker status"                              # Show docker status
alias ldoc="sudo lazydocker"                          # Launch LazyDocker terminal UI

# -----------------------------------------------------------------------------
# TMUX - Terminal multiplexer shortcuts
# -----------------------------------------------------------------------------

alias t="tmux"                                        # Tmux command shortcut
alias ta="tmux attach"                                # Attach to tmux session
alias tl="tmux ls"                                    # List tmux sessions
alias tmn="tmux new -s"                               # Create new tmux session
alias tma="tmux attach -t"                            # Attach to specific tmux session
alias tmd="tmux detach"                               # Detach from tmux session
alias tmk="tmux kill-session -t"                      # Kill specific tmux session

# -----------------------------------------------------------------------------
# ZEROTIER - Software-defined networking shortcuts
# -----------------------------------------------------------------------------

alias zt="sudo zerotier-cli"                          # ZeroTier command line interface
alias ztj="sudo zerotier-cli join"                    # Join ZeroTier network
alias ztl="sudo zerotier-cli listnetworks"            # List joined networks
alias zti="sudo zerotier-cli info"                    # Show ZeroTier information
alias zts="sudo zerotier-cli status"                  # Show ZeroTier status
alias ztq="sudo zerotier-cli leave"                   # Leave ZeroTier network
alias ztqr="sudo zerotier-cli leave -r"               # Leave network with reset
alias zerotier-cli="sudo zerotier-cli"                # ZeroTier CLI (full command)

# -----------------------------------------------------------------------------
# AI STUFF - Artificial intelligence and automation tools
# -----------------------------------------------------------------------------

# Portable Hermes USB launcher. Plug in the Samsung BAR Plus drive, then run:
#   sentinel
#   hermes-usb
#   sentinel-off    stop gateway, sync cleanup, and unmount the USB
# Optional: export ALIASES_REPO=/path/to/aliases if this repo lives somewhere custom.
hermes-portable-usb() {
  local script=""
  local candidates=(
    "$HOME/aliases/install-scripts/hermes-portable-usb.sh"
    "$HOME/code/aliases/install-scripts/hermes-portable-usb.sh"
    "$HOME/.aliases/install-scripts/hermes-portable-usb.sh"
  )
  if [ -n "${ALIASES_REPO:-}" ]; then
    candidates=("$ALIASES_REPO/install-scripts/hermes-portable-usb.sh" "${candidates[@]}")
  fi

  for candidate in "${candidates[@]}"; do
    if [ -x "$candidate" ]; then
      script="$candidate"
      break
    fi
  done

  if [ -z "$script" ]; then
    echo "hermes-portable-usb.sh not found. Set ALIASES_REPO to your aliases repo path." >&2
    return 1
  fi

  "$script" "$@"
}
alias hermesusb="hermes-portable-usb"
alias hermes-usb="hermes-portable-usb"
alias sentinel="hermes-portable-usb"
alias sentinel-off="hermes-portable-usb --off"

# Explicit automode launcher. Set AUTOMODE_CMD to the local autonomous-agent
# command you trust, then run: automode [args...]
automode() {
  if [ -z "${AUTOMODE_CMD:-}" ]; then
    echo "Set AUTOMODE_CMD to the autonomous-agent command you want to run." >&2
    echo "Example: export AUTOMODE_CMD='your-agent --auto'" >&2
    return 1
  fi
  command ${AUTOMODE_CMD} "$@"
}

# =============================================================================
# END OF BASH ALIASES
# =============================================================================