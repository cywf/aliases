#!/usr/bin/env python3
"""
TAK (Team Awareness Kit) Setup Script

This script guides users through setting up TAK (either client or server)
using Docker containers, connected via Zerotier or Tailscale, with options
for custom domains and ArgusTAK integration.

The setup runs in a tmux session with multiple panes showing:
- Main setup process (left)
- System monitoring with btop (top right)
- Setup status and menu (bottom right)
"""

import os
import sys
import time
import subprocess
import shutil
import json
import getpass
import platform
import logging
import argparse
from typing import Dict, List, Tuple, Optional, Union, Callable
import re

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler("tak_setup.log"),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger("TAK-Setup")

# ANSI color codes for terminal output
class Colors:
    HEADER = '\033[95m'
    BLUE = '\033[94m'
    CYAN = '\033[96m'
    GREEN = '\033[92m'
    YELLOW = '\033[93m'
    RED = '\033[91m'
    BOLD = '\033[1m'
    UNDERLINE = '\033[4m'
    END = '\033[0m'

# Configuration dictionary to store user choices
config = {
    "setup_type": None,  # "client" or "server"
    "network_type": None,  # "zerotier" or "tailscale"
    "custom_domain": None,  # domain name or None
    "use_argus": False,  # boolean
    "network_id": None,  # ZeroTier/Tailscale network ID
    "server_address": None,  # Only for client setup
    "data_path": None  # Path to store Docker data
}

def check_dependencies() -> bool:
    """Check if required dependencies are installed."""
    dependencies = ["docker", "tmux", "curl", "python3"]
    
    logger.info("Checking dependencies...")
    missing = []
    
    for dep in dependencies:
        if shutil.which(dep) is None:
            missing.append(dep)
    
    if missing:
        logger.error(f"Missing dependencies: {', '.join(missing)}")
        print(f"{Colors.RED}Error: Missing dependencies: {', '.join(missing)}{Colors.END}")
        
        if platform.system() == "Linux":
            distro = get_linux_distro()
            if distro in ["ubuntu", "debian"]:
                print(f"\nInstall with: {Colors.YELLOW}sudo apt update && sudo apt install -y {' '.join(missing)}{Colors.END}")
            elif distro in ["fedora", "rhel", "centos"]:
                print(f"\nInstall with: {Colors.YELLOW}sudo dnf install -y {' '.join(missing)}{Colors.END}")
            elif distro in ["arch", "manjaro"]:
                print(f"\nInstall with: {Colors.YELLOW}sudo pacman -S {' '.join(missing)}{Colors.END}")
        
        return False
    
    # Check Docker service status
    try:
        subprocess.run(["docker", "info"], check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    except subprocess.CalledProcessError:
        logger.error("Docker service is not running")
        print(f"{Colors.RED}Error: Docker service is not running{Colors.END}")
        print(f"\nStart Docker with: {Colors.YELLOW}sudo systemctl start docker{Colors.END}")
        return False
    
    return True

def get_linux_distro() -> str:
    """Get the Linux distribution name."""
    if os.path.exists("/etc/os-release"):
        with open("/etc/os-release") as f:
            for line in f:
                if line.startswith("ID="):
                    return line.split("=")[1].strip().strip('"')
    return "unknown"

def print_banner():
    """Print a welcome banner for the script."""
    banner = f"""
{Colors.CYAN}╔════════════════════════════════════════════════════════════╗
║                                                            ║
║  {Colors.BOLD}TAK (Team Awareness Kit) Setup Assistant{Colors.END}{Colors.CYAN}                ║
║                                                            ║
║  This wizard will help you set up TAK using Docker,        ║
║  with ZeroTier or Tailscale for connectivity.              ║
║                                                            ║
╚════════════════════════════════════════════════════════════╝{Colors.END}
"""
    print(banner)

def start_tmux_session():
    """Start a new tmux session with the required layout."""
    # Kill existing session if it exists
    subprocess.run(["tmux", "kill-session", "-t", "tak-setup"], 
                  stderr=subprocess.DEVNULL, stdout=subprocess.DEVNULL)
    
    # Create new session
    subprocess.run(["tmux", "new-session", "-d", "-s", "tak-setup"])
    
    # Set up panes:
    # Main pane stays as is (left)
    # Create top-right pane for btop
    subprocess.run(["tmux", "split-window", "-h", "-t", "tak-setup:0.0"])
    # Create bottom-right pane for status
    subprocess.run(["tmux", "split-window", "-v", "-t", "tak-setup:0.1"])
    
    # Resize panes
    subprocess.run(["tmux", "resize-pane", "-t", "tak-setup:0.0", "-R", "25"])
    subprocess.run(["tmux", "resize-pane", "-t", "tak-setup:0.1", "-D", "10"])
    
    # Start btop in the top-right pane
    subprocess.run(["tmux", "send-keys", "-t", "tak-setup:0.1", "btop", "C-m"])
    
    # Display status in bottom-right pane
    subprocess.run(["tmux", "send-keys", "-t", "tak-setup:0.2", 
                   f'echo "{Colors.GREEN}TAK Setup Status:{Colors.END}"; echo ""', "C-m"])
    
    # Attach to the session
    subprocess.run(["tmux", "attach-session", "-t", "tak-setup"])

def update_status(message: str, pane: str = "status"):
    """Update the status message in the tmux status pane."""
    if pane == "status":
        target_pane = "tak-setup:0.2"
    else:
        target_pane = "tak-setup:0.0"
    
    cmd = f'echo "{Colors.YELLOW}{message}{Colors.END}"'
    subprocess.run(["tmux", "send-keys", "-t", target_pane, cmd, "C-m"])

def prompt_user(question: str, options: List[str] = None, default: str = None) -> str:
    """Prompt the user for input with colored text and optional choices."""
    if options:
        option_str = "/".join([f"{Colors.BOLD}{o.upper()}{Colors.END}" if o == default else o for o in options])
        prompt = f"{Colors.CYAN}{question} [{option_str}]: {Colors.END}"
    else:
        default_str = f" (default: {Colors.BOLD}{default}{Colors.END})" if default else ""
        prompt = f"{Colors.CYAN}{question}{default_str}: {Colors.END}"
    
    print(prompt, end="")
    response = input().strip().lower()
    
    if not response and default:
        return default
    
    if options and response not in [o.lower() for o in options]:
        print(f"{Colors.RED}Invalid option. Please choose from: {', '.join(options)}{Colors.END}")
        return prompt_user(question, options, default)
    
    return response

def setup_tak_client():
    """Set up TAK client configuration."""
    update_status("Setting up TAK client...", "main")
    
    # Get server address
    config["server_address"] = prompt_user(
        "Enter the TAK server address (IP or domain)",
        default=config.get("server_address")
    )
    
    # Get data directory
    default_data_dir = os.path.expanduser("~/tak-client-data")
    config["data_path"] = prompt_user(
        "Enter path for TAK client data",
        default=default_data_dir
    )
    
    # Create data directory if it doesn't exist
    os.makedirs(config["data_path"], exist_ok=True)
    
    update_status("TAK client configuration complete!", "status")

def setup_tak_server():
    """Set up TAK server configuration."""
    update_status("Setting up TAK server...", "main")
    
    # Get data directory
    default_data_dir = os.path.expanduser("~/tak-server-data")
    config["data_path"] = prompt_user(
        "Enter path for TAK server data",
        default=default_data_dir
    )
    
    # Create data directory if it doesn't exist
    os.makedirs(config["data_path"], exist_ok=True)
    
    # Ask about custom domain
    use_custom_domain = prompt_user(
        "Do you want to use a custom domain for your TAK server?",
        options=["y", "n"],
        default="n"
    )
    
    if use_custom_domain == "y":
        config["custom_domain"] = prompt_user("Enter your custom domain name")
    
    update_status("TAK server configuration complete!", "status")

def setup_zerotier():
    """Set up ZeroTier networking."""
    update_status("Setting up ZeroTier...", "main")
    
    # Ask for existing network or create new one
    use_existing = prompt_user(
        "Do you want to join an existing ZeroTier network?",
        options=["y", "n"],
        default="n"
    )
    
    if use_existing == "y":
        config["network_id"] = prompt_user("Enter the ZeroTier network ID")
    else:
        # Guide user through creating a new network (placeholder)
        print(f"{Colors.YELLOW}You'll need to create a ZeroTier network at https://my.zerotier.com/{Colors.END}")
        time.sleep(2)
        config["network_id"] = prompt_user("Enter the newly created ZeroTier network ID")
    
    # Install ZeroTier if not already installed
    if shutil.which("zerotier-cli") is None:
        update_status("Installing ZeroTier...", "main")
        try:
            # Install ZeroTier One
            subprocess.run(
                ["curl", "-s", "https://install.zerotier.com", "|", "sudo", "bash"],
                check=True, shell=True
            )
        except subprocess.CalledProcessError as e:
            logger.error(f"Failed to install ZeroTier: {e}")
            print(f"{Colors.RED}Failed to install ZeroTier. Please install manually.{Colors.END}")
            return False
    
    # Join the network
    try:
        subprocess.run(
            ["sudo", "zerotier-cli", "join", config["network_id"]],
            check=True
        )
        print(f"{Colors.GREEN}Successfully joined ZeroTier network!{Colors.END}")
        update_status("ZeroTier setup complete!", "status")
        
    except subprocess.CalledProcessError as e:
        logger.error(f"Failed to join ZeroTier network: {e}")
        print(f"{Colors.RED}Failed to join ZeroTier network. Please check the network ID.{Colors.END}")
        return False
    
    return True

def setup_tailscale():
    """Set up Tailscale networking."""
    update_status("Setting up Tailscale...", "main")
    
    # Install Tailscale if not already installed
    if shutil.which("tailscale") is None:
        update_status("Installing Tailscale...", "main")
        try:
            # Install Tailscale (for Debian/Ubuntu)
            subprocess.run(
                ["curl", "-fsSL", "https://tailscale.com/install.sh", "|", "sudo", "bash"],
                check=True, shell=True
            )
        except subprocess.CalledProcessError as e:
            logger.error(f"Failed to install Tailscale: {e}")
            print(f"{Colors.RED}Failed to install Tailscale. Please install manually.{Colors.END}")
            return False
    
    # Guide user to authenticate with Tailscale
    print(f"{Colors.YELLOW}You'll need to authenticate this device with Tailscale.{Colors.END}")
    try:
        subprocess.run(
            ["sudo", "tailscale", "up"],
            check=True
        )
        print(f"{Colors.GREEN}Successfully connected to Tailscale!{Colors.END}")
        update_status("Tailscale setup complete!", "status")
        
        # Get Tailscale IP for future reference
        result = subprocess.run(
            ["tailscale", "ip", "-4"],
            capture_output=True, text=True, check=True
        )
        config["tailscale_ip"] = result.stdout.strip()
        print(f"{Colors.GREEN}Your Tailscale IP is: {config['tailscale_ip']}{Colors.END}")
        
    except subprocess.CalledProcessError as e:
        logger.error(f"Failed to connect to Tailscale: {e}")
        print(f"{Colors.RED}Failed to connect to Tailscale. Please try manually.{Colors.END}")
        return False
    
    return True

def setup_argus_tak():
    """Set up ArgusTAK integration."""
    update_status("Setting up ArgusTAK integration...", "main")
    
    # This is a placeholder - actual implementation would depend on ArgusTAK specifics
    print(f"{Colors.YELLOW}ArgusTAK setup would be implemented here.{Colors.END}")
    time.sleep(2)
    
    update_status("ArgusTAK setup complete!", "status")
    return True

def deploy_tak_docker():
    """Deploy the TAK Docker containers based on configuration."""
    update_status("Deploying TAK Docker containers...", "main")
    
    # Create docker-compose.yml based on config
    compose_file = os.path.join(config["data_path"], "docker-compose.yml")
    
    if config["setup_type"] == "server":
        create_server_docker_compose(compose_file)
    else:  # client
        create_client_docker_compose(compose_file)
    
    # Start the containers
    try:
        subprocess.run(
            ["docker-compose", "-f", compose_file, "up", "-d"],
            check=True
        )
        print(f"{Colors.GREEN}Successfully started TAK Docker containers!{Colors.END}")
        update_status("TAK Docker containers deployed!", "status")
        return True
        
    except subprocess.CalledProcessError as e:
        logger.error(f"Failed to start Docker containers: {e}")
        print(f"{Colors.RED}Failed to start Docker containers. Check the logs.{Colors.END}")
        return False

def create_server_docker_compose(file_path: str):
    """Create a docker-compose.yml file for the TAK server."""
    # This is a placeholder - the actual Docker Compose file would be more complex
    compose_content = """version: '3'

services:
  tak-server:
    image: takserver/server:latest
    container_name: tak-server
    ports:
      - "8089:8089"
      - "8443:8443"
      - "8446:8446"
    volumes:
      - ./tak-data:/opt/tak/data
    restart: unless-stopped
    environment:
      - TAK_SERVER_EXTERNAL_ADDR=0.0.0.0
"""
    
    if config.get("custom_domain"):
        compose_content += f"      - TAK_SERVER_PUBLIC_URL={config['custom_domain']}\n"
    
    with open(file_path, "w") as f:
        f.write(compose_content)
    
    print(f"{Colors.GREEN}Created docker-compose.yml for TAK server{Colors.END}")

def create_client_docker_compose(file_path: str):
    """Create a docker-compose.yml file for the TAK client."""
    # This is a placeholder - the actual Docker Compose file would be more complex
    compose_content = """version: '3'

services:
  tak-client:
    image: takclient/atak:latest
    container_name: tak-client
    ports:
      - "8080:8080"
    volumes:
      - ./tak-data:/opt/tak/data
    restart: unless-stopped
    environment:
      - TAK_SERVER_ADDRESS=%s
""" % config["server_address"]
    
    with open(file_path, "w") as f:
        f.write(compose_content)
    
    print(f"{Colors.GREEN}Created docker-compose.yml for TAK client{Colors.END}")

def save_config():
    """Save the configuration to a file."""
    config_file = os.path.join(config["data_path"], "tak_setup_config.json")
    
    with open(config_file, "w") as f:
        json.dump(config, f, indent=2)
    
    print(f"{Colors.GREEN}Configuration saved to {config_file}{Colors.END}")

def load_config() -> bool:
    """Load configuration from a file if it exists."""
    config_file = os.path.expanduser("~/tak_setup_config.json")
    
    if os.path.exists(config_file):
        try:
            with open(config_file, "r") as f:
                loaded_config = json.load(f)
                
                for key, value in loaded_config.items():
                    config[key] = value
                
                print(f"{Colors.GREEN}Loaded configuration from {config_file}{Colors.END}")
                return True
                
        except (json.JSONDecodeError, IOError) as e:
            logger.error(f"Failed to load configuration: {e}")
    
    return False

def main():
    """Main function to run the TAK setup process."""
    print_banner()
    
    # Check dependencies
    if not check_dependencies():
        print(f"{Colors.RED}Please install the missing dependencies and try again.{Colors.END}")
        sys.exit(1)
    
    # Try to load existing config
    load_config()
    
    # Set up tmux session
    print(f"{Colors.YELLOW}Setting up tmux session...{Colors.END}")
    start_tmux_session()
    
    # Ask if user wants client or server setup
    config["setup_type"] = prompt_user(
        "Do you want to set up a TAK client or server?",
        options=["client", "server"],
        default=config.get("setup_type", "client")
    )
    
    # Ask which networking solution to use
    config["network_type"] = prompt_user(
        "Which networking solution do you want to use?",
        options=["zerotier", "tailscale"],
        default=config.get("network_type", "zerotier")
    )
    
    # Ask if user wants to use ArgusTAK
    use_argus = prompt_user(
        "Do you want to connect to an existing network via ArgusTAK?",
        options=["y", "n"],
        default="n" if config.get("use_argus") is None else ("y" if config.get("use_argus") else "n")
    )
    config["use_argus"] = (use_argus == "y")
    
    # Perform setup based on user choices
    if config["setup_type"] == "client":
        setup_tak_client()
    else:  # server
        setup_tak_server()
    
    # Set up networking
    if config["network_type"] == "zerotier":
        setup_zerotier()
    else:  # tailscale
        setup_tailscale()
    
    # Set up ArgusTAK if requested
    if config["use_argus"]:
        setup_argus_tak()
    
    # Deploy Docker containers
    deploy_tak_docker()
    
    # Save configuration
    save_config()
    
    print(f"\n{Colors.GREEN}TAK setup complete! Your {config['setup_type']} is now running.{Colors.END}")
    
    # Provide information on how to access the TAK system
    if config["setup_type"] == "server":
        if config.get("custom_domain"):
            print(f"\nAccess your TAK server at: {Colors.CYAN}https://{config['custom_domain']}:8443{Colors.END}")
        elif config["network_type"] == "tailscale" and config.get("tailscale_ip"):
            print(f"\nAccess your TAK server at: {Colors.CYAN}https://{config['tailscale_ip']}:8443{Colors.END}")
        else:
            print(f"\nAccess your TAK server through your ZeroTier network IP at port 8443")
    else:  # client
        print(f"\nYour TAK client is connected to: {Colors.CYAN}{config['server_address']}{Colors.END}")
    
    print(f"\n{Colors.YELLOW}To detach from the tmux session, press Ctrl+B followed by D{Colors.END}")
    print(f"{Colors.YELLOW}To reattach later, run: tmux attach-session -t tak-setup{Colors.END}")

if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print(f"\n\n{Colors.YELLOW}Setup cancelled by user.{Colors.END}")
        sys.exit(0)
    except Exception as e:
        logger.error(f"Unexpected error: {e}", exc_info=True)
        print(f"\n{Colors.RED}An unexpected error occurred: {e}{Colors.END}")
        print(f"Check the log file for details: tak_setup.log")
        sys.exit(1) 
