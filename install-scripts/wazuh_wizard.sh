#!/bin/bash

# ------------------ #
# Wazuh Setup Script #
# ------------------ #

# Enable strict error handling
set -euo pipefail
IFS=$'\n\t'

# Script information
readonly SCRIPT_VERSION="1.0.0"
readonly SCRIPT_NAME=$(basename "$0")
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly START_TIME=$(date)
readonly LOG_FILE="${SCRIPT_DIR}/wazuh_setup.log"

# Installation steps tracking
declare -a STEPS=(
    "Checking Prerequisites"
    "Configuring Network"
    "Setting up Domain"
    "Installing Docker"
    "Configuring Services"
    "Starting Containers"
    "Verifying Installation"
)
TOTAL_STEPS=${#STEPS[@]}
CURRENT_STEP=0

# Configuration variables
read -p "Enter Docker Compose version (default: 2.21.0): " DOCKER_COMPOSE_VERSION
DOCKER_COMPOSE_VERSION=${DOCKER_COMPOSE_VERSION:-2.21.0}

read -p "Enter your domain: " DOMAIN

read -p "Enter your email: " EMAIL

read -p "Do you want to use SSL? (y/n, default: n): " USE_SSL_INPUT
USE_SSL=false
if [[ "$USE_SSL_INPUT" =~ ^[Yy]$ ]]; then
    USE_SSL=true
fi

read -p "Enter your public IP (leave blank to auto-detect): " PUBLIC_IP

read -p "Enter your ZeroTier IP (if applicable): " ZEROTIER_IP

read -p "Enter your ZeroTier Network ID (if applicable): " ZEROTIER_NETWORK_ID

read -p "Do you want to use Cloudflare? (y/n, default: n): " USE_CLOUDFLARE_INPUT
USE_CLOUDFLARE=false
if [[ "$USE_CLOUDFLARE_INPUT" =~ ^[Yy]$ ]]; then
    USE_CLOUDFLARE=true
fi

# Colors for output
declare -A COLORS=(
    [INFO]="\e[34m"     # Blue
    [SUCCESS]="\e[32m"  # Green
    [ERROR]="\e[31m"    # Red
    [WARNING]="\e[33m"  # Yellow
    [RESET]="\e[0m"     # Reset
    [CYAN]="\e[36m"     # Cyan
    [MAGENTA]="\e[35m"  # Magenta
)

# Function to initialize logging
init_logging() {
    # Create the directory for the log file if it doesn't exist
    mkdir -p "$(dirname "$LOG_FILE")"
    
    # Initialize the log file with a header
    cat > "$LOG_FILE" << EOF
==============================================
Wazuh Installation Log
Started at: $START_TIME
Script Version: $SCRIPT_VERSION
==============================================

EOF

    # Set permissions to ensure the log file is secure
    chmod 600 "$LOG_FILE"
    
    # Print a message indicating that logging has been initialized
    echo "Logging initialized. Log file: $LOG_FILE"
}

# Function to log messages
log_message() {
    local level="$1"    # Log level (e.g., INFO, ERROR, WARNING)
    local message="$2"  # Message to log

    # Get the current timestamp
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    # Format and append the log message to the log file
    echo "[${timestamp}] [${level}] ${message}" >> "$LOG_FILE"
}

# Function to print status messages
print_status() {
    local message="$1"  # Message to print
    local level="${2:-INFO}"  # Log level, default to INFO if not provided

    # Determine the color based on the log level
    local color="${COLORS[$level]:-${COLORS[INFO]}}"

    # Print the message to the console with color
    echo -e "${color}[$(date +"%Y-%m-%d %H:%M:%S")] $message${COLORS[RESET]}"

    # Log the message to the log file
    log_message "$level" "$message"
}

# Function to show ASCII banners
show_banner() {
    local banner_type="$1"  # Type of banner to display

    # Clear the console for a clean display
    clear

    # Display the appropriate banner based on the type
    case "$banner_type" in
        "main")
            cat << "EOF"
 __          __              _     
 \ \        / /             | |    
  \ \  /\  / /_ _ _____   _| |__  
   \ \/  \/ / _` |_  / | | | '_ \ 
    \  /\  / (_| |/ /| |_| | | | |
     \/  \/ \__,_/___|\__,_|_| |_|
                                  
    Docker Installation Wizard
EOF
            ;;
        "error")
            cat << "EOF"
  _____ ____  ____   ___  ____  
 | ____|  _ \|  _ \ / _ \|  _ \ 
 |  _| | |_) | |_) | | | | |_) |
 | |___|  _ <|  _ <| |_| |  _ < 
 |_____|_| \_\_| \_\\___/|_| \_\
                                
EOF
            ;;
        "success")
            cat << "EOF"
  ____  _   _  ____ ____ _____ ____ ____  
 / ___|| | | |/ ___/ ___| ____/ ___/ ___| 
 \___ \| | | | |  | |   |  _| \___ \___ \ 
  ___) | |_| | |__| |___| |___ ___) |__) |
 |____/ \___/ \____\____|_____|____/____/ 
                                          
EOF
            ;;
        *)
            echo "Unknown banner type: $banner_type"
            ;;
    esac

    # Print additional information
    echo -e "\n${COLORS[CYAN]}Version: $SCRIPT_VERSION${COLORS[RESET]}"
    echo -e "${COLORS[CYAN]}Started at: $(date)${COLORS[RESET]}"
    echo -e "${COLORS[CYAN]}----------------------------------------${COLORS[RESET]}\n"
}

# Function to show progress
show_progress() {
    local current=$1  # Current step number
    local total=$2    # Total number of steps
    local width=50    # Width of the progress bar

    # Calculate the percentage of completion
    local percentage=$((current * 100 / total))
    # Calculate the number of completed segments in the progress bar
    local completed=$((width * current / total))
    # Calculate the number of remaining segments in the progress bar
    local remaining=$((width - completed))

    # Create a spinner for visual effect
    local spinner=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
    local spin_idx=$((current % ${#spinner[@]}))

    # Print the progress bar with the spinner
    printf "\r${COLORS[CYAN]}[${spinner[$spin_idx]}] Progress: [%${completed}s%${remaining}s] %d%%${COLORS[RESET]}" \
           "$(printf '#%.0s' $(seq 1 $completed))" \
           "$(printf ' %.0s' $(seq 1 $remaining))" \
           "$percentage"
}

# Function to update progress
update_progress() {
    # Increment the current step
    ((CURRENT_STEP++))

    # Call the show_progress function to update the display
    show_progress "$CURRENT_STEP" "$TOTAL_STEPS"
}

# Function to retry a command
retry_command() {
    local retries=3      # Number of retry attempts
    local count=0        # Current attempt count
    local delay=5        # Delay between attempts in seconds
    local command="$@"   # Command to execute

    # Attempt to execute the command up to the specified number of retries
    until [ $count -ge $retries ]; do
        # Execute the command
        $command && break

        # Increment the attempt count
        count=$((count + 1))

        # Print a warning message and wait before retrying
        print_status "Command failed. Attempt $count/$retries. Retrying in $delay seconds..." "WARNING"
        sleep $delay
    done

    # Check if the command failed after all attempts
    if [ $count -ge $retries ]; then
        print_status "Command failed after $retries attempts." "ERROR"
        return 1
    fi

    return 0
}

# Interactive error handling
handle_error() {
    local error_message="$1"  # Error message to display
    local line_number="$2"    # Line number where the error occurred

    # Print the error message and line number
    print_status "$error_message" "ERROR"
    print_status "Error occurred on line $line_number." "ERROR"

    # Interactive loop to handle the error
    while true; do
        echo -e "${COLORS[WARNING]}Would you like to (r)etry, (s)kip, or (e)xit?${COLORS[RESET]}"
        read -p "Enter your choice: " choice
        case $choice in
            [Rr]* ) return 1;;  # Retry the step
            [Ss]* ) return 0;;  # Skip the step
            [Ee]* ) cleanup_on_error 1 $line_number;;  # Exit the script
            * ) echo "Please answer r, s, or e.";;  # Prompt for valid input
        esac
    done
}

# Function to configure network
configure_network() {
    print_status "Configuring network..." "INFO"

    # Join ZeroTier network if a network ID is provided
    if [ -n "$ZEROTIER_NETWORK_ID" ]; then
        if ! command -v zerotier-cli &> /dev/null; then
            print_status "ZeroTier CLI is not installed. Please install it first." "ERROR"
            return 1
        fi

        retry_command zerotier-cli join "$ZEROTIER_NETWORK_ID"
        if [ $? -ne 0 ]; then
            print_status "Failed to join ZeroTier network after multiple attempts." "ERROR"
            return 1
        fi

        ZEROTIER_IP=$(zerotier-cli listnetworks | grep "$ZEROTIER_NETWORK_ID" | awk '{print $NF}')
        print_status "Joined ZeroTier network with IP: $ZEROTIER_IP" "SUCCESS"
    fi

    # Attempt to detect Docker network IP
    DOCKER_NETWORK_INTERFACE="docker0"
    DOCKER_IP=$(ip addr show "$DOCKER_NETWORK_INTERFACE" | grep 'inet ' | awk '{print $2}' | cut -d/ -f1)

    if [[ -n "$DOCKER_IP" ]]; then
        PUBLIC_IP="$DOCKER_IP"
        print_status "Detected Docker network IP: $PUBLIC_IP" "INFO"
    else
        print_status "Failed to detect Docker network IP. Falling back to local IP address." "WARNING"
        PUBLIC_IP=$(hostname -I | awk '{print $1}')
        if [[ -n "$PUBLIC_IP" ]]; then
            print_status "Detected local IP: $PUBLIC_IP" "INFO"
        else
            print_status "Failed to detect any IP address." "ERROR"
            return 1
        fi
    fi

    return 0
}

# Function to check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..." "INFO"

    # Check for root privileges
    if [ "$EUID" -ne 0 ]; then
        print_status "This script must be run as root" "ERROR"
        return 1
    fi

    # Check for curl
    if ! command -v curl &> /dev/null; then
        print_status "curl is not installed. Please install curl first." "ERROR"
        return 1
    fi

    # Check for Docker
    if ! command -v docker &> /dev/null; then
        print_status "Docker is not installed. Please install Docker first." "ERROR"
        return 1
    fi

    # Check for Docker Compose
    if ! command -v docker-compose &> /dev/null; then
        print_status "Docker Compose is not installed. Please install Docker Compose first." "ERROR"
        return 1
    fi

    # Check for ZeroTier CLI if ZeroTier network ID is provided
    if [ -n "$ZEROTIER_NETWORK_ID" ] && ! command -v zerotier-cli &> /dev/null; then
        print_status "ZeroTier CLI is not installed. Please install ZeroTier CLI first." "ERROR"
        return 1
    fi

    print_status "All prerequisites are met." "SUCCESS"
    return 0
}

# Function to install Docker
install_docker() {
    print_status "Installing Docker..." "INFO"

    # Check if Docker is already installed
    if command -v docker &> /dev/null; then
        print_status "Docker is already installed." "SUCCESS"
        return 0
    fi

    # Download and run the Docker installation script
    retry_command curl -fsSL https://get.docker.com -o get-docker.sh
    if [ $? -ne 0 ]; then
        print_status "Failed to download Docker installation script." "ERROR"
        return 1
    fi

    # Execute the Docker installation script
    sh get-docker.sh
    rm get-docker.sh

    # Start and enable Docker service
    systemctl start docker
    systemctl enable docker

    # Verify Docker installation
    if command -v docker &> /dev/null; then
        print_status "Docker installed successfully." "SUCCESS"
        return 0
    else
        print_status "Docker installation failed." "ERROR"
        return 1
    fi
}

# Function to install Docker Compose
install_docker_compose() {
    print_status "Installing Docker Compose..." "INFO"

    # Check if Docker Compose is already installed
    if command -v docker-compose &> /dev/null; then
        print_status "Docker Compose is already installed." "SUCCESS"
        return 0
    fi

    # Download Docker Compose binary
    local compose_url="https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)"
    retry_command curl -L "$compose_url" -o /usr/local/bin/docker-compose
    if [ $? -ne 0 ]; then
        print_status "Failed to download Docker Compose." "ERROR"
        return 1
    fi

    # Make the Docker Compose binary executable
    chmod +x /usr/local/bin/docker-compose

    # Verify Docker Compose installation
    if command -v docker-compose &> /dev/null; then
        print_status "Docker Compose installed successfully." "SUCCESS"
        return 0
    else
        print_status "Docker Compose installation failed. Please check the installation path." "ERROR"
        return 1
    fi
}

# Function to set up domain
setup_domain() {
    print_status "Setting up domain..." "INFO"

    # Check if a domain is specified
    if [ -z "$DOMAIN" ]; then
        print_status "No domain specified. Setting up local domain configuration." "WARNING"
        
        # Set a default local domain name
        DOMAIN="localhost.localdomain"
        
        # Optionally, add an entry to the /etc/hosts file
        if ! grep -q "$DOMAIN" /etc/hosts; then
            echo "127.0.0.1 $DOMAIN" | sudo tee -a /etc/hosts > /dev/null
            print_status "Local domain $DOMAIN added to /etc/hosts." "INFO"
        else
            print_status "Local domain $DOMAIN already exists in /etc/hosts." "INFO"
        fi
    else
        # Validate domain format
        if ! [[ "$DOMAIN" =~ ^[a-zA-Z0-9.-]+$ ]]; then
            print_status "Invalid domain format: $DOMAIN" "ERROR"
            return 1
        fi
    fi

    # Example: Additional domain setup steps can be added here
    # For instance, configuring DNS records or SSL certificates

    print_status "Domain $DOMAIN is valid and set up." "SUCCESS"
    return 0
}

# Function to generate Docker Compose configuration
generate_docker_compose() {
    print_status "Generating Docker Compose configuration..." "INFO"

    # Define the installation directory for Docker Compose
    local install_dir="/opt/wazuh-docker"
    mkdir -p "$install_dir"

    # Create the Docker Compose configuration file
    cat > "$install_dir/docker-compose.yml" << EOF
version: '3.9'
services:
  wazuh:
    image: wazuh/wazuh
    ports:
      - "1514:1514"
      - "1515:1515"
      - "55000:55000"
    environment:
      - WAZUH_MANAGER_IP=$PUBLIC_IP
    volumes:
      - wazuh_data:/var/ossec/data
  elasticsearch:
    image: docker.elastic.co/elasticsearch/elasticsearch:7.10.2
    environment:
      - discovery.type=single-node
    volumes:
      - es_data:/usr/share/elasticsearch/data
  kibana:
    image: docker.elastic.co/kibana/kibana:7.10.2
    ports:
      - "5601:5601"
    environment:
      - ELASTICSEARCH_HOSTS=http://elasticsearch:9200
volumes:
  wazuh_data:
  es_data:
EOF

    # Log success message
    print_status "Docker Compose configuration generated successfully." "SUCCESS"
    return 0
}

# Function to set up SSL
setup_ssl() {
    print_status "Setting up SSL..." "INFO"

    # Check if SSL is enabled
    if [ "$USE_SSL" = false ]; then
        print_status "SSL is not enabled. Skipping SSL setup." "WARNING"
        return 0
    fi

    # Check if Certbot is installed
    if ! command -v certbot &> /dev/null; then
        print_status "Certbot is not installed. Please install Certbot first." "ERROR"
        return 1
    fi

    # Obtain SSL certificate using Certbot
    retry_command certbot certonly --standalone -d "$DOMAIN" --email "$EMAIL" --agree-tos --non-interactive
    if [ $? -ne 0 ]; then
        print_status "Failed to obtain SSL certificate for $DOMAIN after multiple attempts." "ERROR"
        return 1
    fi

    # Verify the SSL certificate directory
    if [ ! -d "/etc/letsencrypt/live/$DOMAIN" ]; then
        print_status "SSL certificate directory not found for $DOMAIN" "ERROR"
        return 1
    fi

    print_status "SSL certificate obtained for $DOMAIN" "SUCCESS"
    return 0
}

# Function to start Docker containers
start_wazuh_services() {
    print_status "Starting Wazuh services..." "INFO"

    # Define the installation directory for Docker Compose
    local install_dir="/opt/wazuh-docker"

    # Check if the Docker Compose configuration file exists
    if [ ! -f "$install_dir/docker-compose.yml" ]; then
        print_status "Docker Compose configuration not found. Cannot start services." "ERROR"
        return 1
    fi

    # Navigate to the installation directory
    cd "$install_dir"

    # Start the Docker containers using Docker Compose
    retry_command docker-compose up -d
    if [ $? -ne 0 ]; then
        print_status "Failed to start Docker containers after multiple attempts." "ERROR"
        return 1
    fi

    print_status "Wazuh services started successfully." "SUCCESS"
    return 0
}

# Function to verify installation
verify_complete_installation() {
    print_status "Verifying installation..." "INFO"

    # Check if Wazuh service is running
    if ! docker ps | grep -q wazuh; then
        print_status "Wazuh service is not running." "ERROR"
        return 1
    fi

    # Check if Elasticsearch service is running
    if ! docker ps | grep -q elasticsearch; then
        print_status "Elasticsearch service is not running." "ERROR"
        return 1
    fi

    # Check if Kibana service is running
    if ! docker ps | grep -q kibana; then
        print_status "Kibana service is not running." "ERROR"
        return 1
    fi

    print_status "All services are running successfully." "SUCCESS"
    return 0
}

# Function to save installation details
save_installation_details() {
    print_status "Saving installation details..." "INFO"

    # Define the file to save installation details
    local details_file="${SCRIPT_DIR}/installation_details.txt"

    # Write installation details to the file
    cat > "$details_file" << EOF
==============================================
Wazuh Installation Details
Completed at: $(date)
Script Version: $SCRIPT_VERSION
==============================================

Public IP: $PUBLIC_IP
Domain: $DOMAIN
SSL Enabled: $USE_SSL
Docker Compose Version: $DOCKER_COMPOSE_VERSION

Services:
- Wazuh
- Elasticsearch
- Kibana

EOF

    # Log success message
    print_status "Installation details saved to $details_file" "SUCCESS"
}

# Function to handle cleanup on error
cleanup_on_error() {
    local exit_code="$1"    # Exit code to return
    local line_number="$2"  # Line number where the error occurred

    print_status "Cleaning up after error..." "ERROR"

    # Define the installation directory for Docker Compose
    local install_dir="/opt/wazuh-docker"

    # Stop Docker containers if they are running
    if [ -f "$install_dir/docker-compose.yml" ]; then
        cd "$install_dir"
        docker-compose down
        print_status "Stopped Docker containers." "INFO"
    fi

    # Remove temporary files or directories if needed
    # Example: rm -rf /path/to/temp/dir

    # Log the error and exit
    print_status "Cleanup completed. Exiting with code $exit_code." "ERROR"
    exit "$exit_code"
}

# Main function to orchestrate the setup
main() {
    # Show the main banner
    show_banner "main"

    # Initialize logging
    init_logging

    # Check prerequisites
    if ! check_prerequisites; then
        handle_error "Prerequisite check failed" $LINENO
    fi

    # Configure network
    if ! configure_network; then
        handle_error "Network configuration failed" $LINENO
    fi

    # Set up domain
    if ! setup_domain; then
        handle_error "Domain setup failed" $LINENO
    fi

    # Install Docker
    if ! install_docker; then
        handle_error "Docker installation failed" $LINENO
    fi

    # Install Docker Compose
    if ! install_docker_compose; then
        handle_error "Docker Compose installation failed" $LINENO
    fi

    # Generate Docker Compose configuration
    if ! generate_docker_compose; then
        handle_error "Failed to generate Docker Compose configuration" $LINENO
    fi

    # Setup SSL if enabled
    if ! setup_ssl; then
        handle_error "SSL setup failed" $LINENO
    fi

    # Start Wazuh services
    if ! start_wazuh_services; then
        handle_error "Failed to start Wazuh services" $LINENO
    fi

    # Verify installation
    if ! verify_complete_installation; then
        handle_error "Installation verification failed" $LINENO
    fi

    # Save installation details
    save_installation_details

    # Show success banner
    show_banner "success"
    print_status "Installation completed successfully." "SUCCESS"

    return 0
}

# Start script execution
main "$@"
