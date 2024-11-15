#!/bin/bash

# Enhanced Wazuh setup script with Docker support, improved network handling,
# and comprehensive domain/DNS management

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

# Configuration variables (will be set through user input)
DOCKER_COMPOSE_VERSION="2.21.0"
DOMAIN=""
EMAIL=""
USE_SSL=false
PUBLIC_IP=""
ZEROTIER_IP=""
ZEROTIER_NETWORK_ID=""
USE_CLOUDFLARE=false

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
    mkdir -p "$(dirname "$LOG_FILE")"
    cat > "$LOG_FILE" << EOF
==============================================
Wazuh Installation Log
Started at: $START_TIME
Script Version: $SCRIPT_VERSION
==============================================

EOF
    chmod 600 "$LOG_FILE"
}

# Function to log messages
log_message() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[${timestamp}] [${level}] ${message}" >> "$LOG_FILE"
}

# Function to print status messages
print_status() {
    local message="$1"
    local level="${2:-INFO}"
    local color="${COLORS[$level]:-${COLORS[INFO]}}"
    echo -e "${color}[$(date +"%Y-%m-%d %H:%M:%S")] $message${COLORS[RESET]}"
    log_message "$level" "$message"
}

# Function to show ASCII banners
show_banner() {
    local banner_type="$1"
    clear
    
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
    esac
    
    echo -e "\n${COLORS[CYAN]}Version: $SCRIPT_VERSION${COLORS[RESET]}"
    echo -e "${COLORS[CYAN]}Started at: $(date)${COLORS[RESET]}"
    echo -e "${COLORS[CYAN]}----------------------------------------${COLORS[RESET]}\n"
}

# Function to show progress
show_progress() {
    local current=$1
    local total=$2
    local width=50
    local percentage=$((current * 100 / total))
    local completed=$((width * current / total))
    local remaining=$((width - completed))
    local spinner=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
    local spin_idx=$((current % ${#spinner[@]}))
    
    printf "\r${COLORS[CYAN]}[${spinner[$spin_idx]}] Progress: [%${completed}s%${remaining}s] %d%%${COLORS[RESET]}" \
           "$(printf '#%.0s' $(seq 1 $completed))" \
           "$(printf ' %.0s' $(seq 1 $remaining))" \
           "$percentage"
}

# Function to update progress
update_progress() {
    ((CURRENT_STEP++))
    show_progress "$CURRENT_STEP" "$TOTAL_STEPS"
}

# Function to retry a command
retry_command() {
    local retries=3
    local count=0
    local delay=5
    local command="$@"
    
    until [ $count -ge $retries ]; do
        $command && break
        count=$((count + 1))
        print_status "Command failed. Attempt $count/$retries. Retrying in $delay seconds..." "WARNING"
        sleep $delay
    done
    
    if [ $count -ge $retries ]; then
        print_status "Command failed after $retries attempts." "ERROR"
        return 1
    fi
    return 0
}

# Interactive error handling
handle_error() {
    local error_message="$1"
    local line_number="$2"
    
    print_status "$error_message" "ERROR"
    print_status "Error occurred on line $line_number." "ERROR"
    
    while true; do
        echo -e "${COLORS[WARNING]}Would you like to (r)etry, (s)kip, or (e)xit?${COLORS[RESET]}"
        read -p "Enter your choice: " choice
        case $choice in
            [Rr]* ) return 1;;  # Retry the step
            [Ss]* ) return 0;;  # Skip the step
            [Ee]* ) cleanup_on_error 1 $line_number;;  # Exit the script
            * ) echo "Please answer r, s, or e.";;
        esac
    done
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
    
    print_status "All prerequisites are met." "SUCCESS"
    return 0
}

# Function to configure network
configure_network() {
    print_status "Configuring network..." "INFO"
    
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
    
    if [ -z "$PUBLIC_IP" ]; then
        retry_command PUBLIC_IP=$(dig +short myip.opendns.com @resolver1.opendns.com)
        if [ $? -ne 0 ]; then
            print_status "Failed to detect public IP after multiple attempts." "ERROR"
            return 1
        fi
        print_status "Detected public IP: $PUBLIC_IP" "INFO"
    fi
    
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
    
    # Install Docker
    retry_command curl -fsSL https://get.docker.com -o get-docker.sh
    if [ $? -ne 0 ]; then
        print_status "Failed to download Docker installation script." "ERROR"
        return 1
    fi
    
    sh get-docker.sh
    rm get-docker.sh
    
    # Start Docker service
    systemctl start docker
    systemctl enable docker
    
    print_status "Docker installed successfully." "SUCCESS"
    return 0
}

# Function to install Docker Compose
install_docker_compose() {
    print_status "Installing Docker Compose..." "INFO"
    
    # Check if Docker Compose is already installed
    if command -v docker-compose &> /dev/null; then
        print_status "Docker Compose is already installed." "SUCCESS"
        return 0
    fi
    
    # Install Docker Compose
    retry_command curl -L "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    if [ $? -ne 0 ]; then
        print_status "Failed to download Docker Compose." "ERROR"
        return 1
    fi
    
    chmod +x /usr/local/bin/docker-compose
    
    # Verify Docker Compose installation
    if ! command -v docker-compose &> /dev/null; then
        print_status "Docker Compose installation failed. Please check the installation path." "ERROR"
        return 1
    fi
    
    print_status "Docker Compose installed successfully." "SUCCESS"
    return 0
}

# Function to set up domain
setup_domain() {
    print_status "Setting up domain..." "INFO"
    
    if [ -z "$DOMAIN" ]; then
        print_status "No domain specified. Skipping domain setup." "WARNING"
        return 0
    fi
    
    # Example: Validate domain format
    if ! [[ "$DOMAIN" =~ ^[a-zA-Z0-9.-]+$ ]]; then
        print_status "Invalid domain format: $DOMAIN" "ERROR"
        return 1
    fi
    
    print_status "Domain $DOMAIN is valid." "SUCCESS"
    return 0
}

# Function to generate Docker Compose configuration
generate_docker_compose() {
    print_status "Generating Docker Compose configuration..." "INFO"
    
    local install_dir="/opt/wazuh-docker"
    mkdir -p "$install_dir"
    
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

    print_status "Docker Compose configuration generated successfully." "SUCCESS"
    return 0
}

# Function to set up SSL
setup_ssl() {
    print_status "Setting up SSL..." "INFO"
    
    if [ "$USE_SSL" = false ]; then
        print_status "SSL is not enabled. Skipping SSL setup." "WARNING"
        return 0
    fi
    
    # Example: Use Let's Encrypt for SSL
    if ! command -v certbot &> /dev/null; then
        print_status "Certbot is not installed. Please install Certbot first." "ERROR"
        return 1
    fi
    
    retry_command certbot certonly --standalone -d "$DOMAIN" --email "$EMAIL" --agree-tos --non-interactive
    if [ $? -ne 0 ]; then
        print_status "Failed to obtain SSL certificate for $DOMAIN after multiple attempts." "ERROR"
        return 1
    fi
    
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
    
    local install_dir="/opt/wazuh-docker"
    if [ ! -f "$install_dir/docker-compose.yml" ]; then
        print_status "Docker Compose configuration not found. Cannot start services." "ERROR"
        return 1
    fi
    
    cd "$install_dir"
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
    
    # Check if Wazuh services are running
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
    
    local details_file="${SCRIPT_DIR}/installation_details.txt"
    cat > "$details_file" << EOF
Wazuh Installation Details
===========================
Installation Date: $(date)
Public IP: $PUBLIC_IP
Domain: $DOMAIN
SSL Enabled: $USE_SSL
Docker Compose Version: $DOCKER_COMPOSE_VERSION
EOF

    print_status "Installation details saved to $details_file" "SUCCESS"
    return 0
}

# Function to handle cleanup on error
cleanup_on_error() {
    local error_code="$1"
    local line_number="$2"
    
    print_status "An error occurred. Cleaning up..." "ERROR"
    print_status "Error occurred on line $line_number." "ERROR"
    
    # Stop Docker containers
    local install_dir="/opt/wazuh-docker"
    if [ -f "$install_dir/docker-compose.yml" ]; then
        cd "$install_dir"
        docker-compose down
    fi
    
    # Remove installation directory
    rm -rf /opt/wazuh-docker
    
    # Leave ZeroTier network
    if [ -n "$ZEROTIER_NETWORK_ID" ]; then
        zerotier-cli leave "$ZEROTIER_NETWORK_ID"
    fi
    
    print_status "Cleanup completed. Check $LOG_FILE for details." "INFO"
    exit $error_code
}

# Main function
main() {
    # Initialize logging
    init_logging
    
    # Set up error handling
    trap 'handle_error "An unexpected error occurred." $LINENO' ERR
    
    # Show main banner
    show_banner "main"
    
    # Check prerequisites
    if ! check_prerequisites; then
        handle_error "Prerequisites check failed" $LINENO
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
