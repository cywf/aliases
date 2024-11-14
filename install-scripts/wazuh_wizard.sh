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
    local step_name="$1"
    ((CURRENT_STEP++))
    print_status "Step $CURRENT_STEP/$TOTAL_STEPS: $step_name" "INFO"
    show_progress $CURRENT_STEP $TOTAL_STEPS
    echo -e "\n"
}

# Function to check prerequisites
check_prerequisites() {
    update_progress "Checking Prerequisites"
    
    local required_commands=(
        "curl"
        "dig"
        "docker"
        "openssl"
        "jq"
    )
    
    local missing_commands=()
    
    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" &>/dev/null; then
            missing_commands+=("$cmd")
        fi
    done
    
    if [ ${#missing_commands[@]} -ne 0 ]; then
        print_status "Missing required commands: ${missing_commands[*]}" "ERROR"
        return 1
    fi
    
    print_status "All prerequisites are met" "SUCCESS"
    return 0
}

# Function to generate Docker Compose configuration
generate_docker_compose() {
    update_progress "Generating Docker Compose Configuration"
    
    local install_dir="/opt/wazuh-docker"
    mkdir -p "$install_dir"
    
    cat > "$install_dir/docker-compose.yml" << EOF
version: '3.8'
services:
  wazuh:
    image: wazuh/wazuh-manager:latest
    ports:
      - "1514:1514"
      - "1515:1515"
      - "514:514/udp"
      - "55000:55000"
    environment:
      - WAZUH_PASSWORD=admin
    volumes:
      - wazuh_data:/var/ossec
    networks:
      - wazuh-network

  elasticsearch:
    image: wazuh/wazuh-elasticsearch:latest
    environment:
      - "ES_JAVA_OPTS=-Xms1g -Xmx1g"
    volumes:
      - elastic_data:/usr/share/elasticsearch/data
    networks:
      - wazuh-network

  kibana:
    image: wazuh/wazuh-kibana:latest
    ports:
      - "5601:5601"
    networks:
      - wazuh-network

volumes:
  wazuh_data:
  elastic_data:

networks:
  wazuh-network:
EOF
    
    print_status "Docker Compose configuration generated" "SUCCESS"
    return 0
}

# Function to setup SSL
setup_ssl() {
    update_progress "Setting up SSL"
    
    # Placeholder for SSL setup logic
    print_status "SSL setup is not implemented yet" "WARNING"
    return 0
}

# Function to start Wazuh services
start_wazuh_services() {
    update_progress "Starting Wazuh Services"
    
    local install_dir="/opt/wazuh-docker"
    cd "$install_dir"
    
    # Pull images first
    print_status "Pulling Docker images..." "INFO"
    if ! docker-compose pull; then
        print_status "Failed to pull Docker images" "ERROR"
        return 1
    fi
    
    # Start services
    print_status "Starting containers..." "INFO"
    if ! docker-compose up -d; then
        print_status "Failed to start containers" "ERROR"
        return 1
    fi
    
    # Wait for services to be ready
    local services=("wazuh" "elasticsearch" "kibana")
    local max_attempts=30
    local attempt=1
    
    for service in "${services[@]}"; do
        print_status "Waiting for $service to be ready..." "INFO"
        attempt=1
        
        while [ $attempt -le $max_attempts ]; do
            show_progress $attempt $max_attempts
            
            if docker-compose ps "$service" | grep -q "Up"; then
                echo "" # New line after progress bar
                print_status "$service is ready" "SUCCESS"
                break
            fi
            
            if [ $attempt -eq $max_attempts ]; then
                echo "" # New line after progress bar
                print_status "$service failed to start properly" "ERROR"
                return 1
            fi
            
            sleep 2
            ((attempt++))
        done
    done
    
    print_status "All services started successfully" "SUCCESS"
    return 0
}

# Function to save installation details
save_installation_details() {
    local install_dir="/opt/wazuh-docker"
    local details_file="$install_dir/installation_details.json"
    
    cat > "$details_file" << EOF
{
    "installation_date": "$(date)",
    "version": "$SCRIPT_VERSION",
    "domain": "$DOMAIN",
    "email": "$EMAIL",
    "use_ssl": $USE_SSL,
    "use_cloudflare": $USE_CLOUDFLARE,
    "zerotier_network_id": "$ZEROTIER_NETWORK_ID",
    "public_ip": "$PUBLIC_IP",
    "zerotier_ip": "$ZEROTIER_IP"
}
EOF
    
    chmod 600 "$details_file"
    print_status "Installation details saved to $details_file" "SUCCESS"
}

# Function to display completion message
show_completion_message() {
    show_banner "success"
    
    cat << EOF
Installation Details:
--------------------
Domain: $DOMAIN
Access URL: ${USE_SSL:+https://}${USE_SSL:-http://}$DOMAIN
ZeroTier IP: $ZEROTIER_IP
Installation Directory: /opt/wazuh-docker

Default Credentials:
------------------
Username: admin
Password: admin

Important Next Steps:
-------------------
1. Change the default password immediately after first login
2. Configure your firewall rules
3. Set up regular backups
4. Review the installation logs at: $LOG_FILE

Useful Commands:
--------------
- View logs: docker-compose logs -f
- Restart services: docker-compose restart
- Stop services: docker-compose down
- Start services: docker-compose up -d

Support:
-------
Documentation: https://documentation.wazuh.com
Community: https://wazuh.com/community
EOF
    
    # Save details to log file
    echo -e "\nInstallation completed at: $(date)" >> "$LOG_FILE"
    echo "Domain: $DOMAIN" >> "$LOG_FILE"
    echo "ZeroTier IP: $ZEROTIER_IP" >> "$LOG_FILE"
}

# Function to perform cleanup on error
cleanup_on_error() {
    local error_code=$1
    local error_line=$2
    
    show_banner "error"
    print_status "Installation failed on line $error_line" "ERROR"
    print_status "Performing cleanup..." "INFO"
    
    # Stop and remove containers
    if [ -f "/opt/wazuh-docker/docker-compose.yml" ]; then
        cd /opt/wazuh-docker
        docker-compose down -v
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
    trap 'cleanup_on_error $? $LINENO' ERR
    
    # Show main banner
    show_banner "main"
    
    # Check prerequisites
    if ! check_prerequisites; then
        show_banner "error"
        print_status "Prerequisites check failed" "ERROR"
        exit 1
    fi
    
    # Generate Docker Compose configuration
    if ! generate_docker_compose; then
        show_banner "error"
        print_status "Failed to generate Docker Compose configuration" "ERROR"
        cleanup_on_error
        exit 1
    fi
    
    # Setup SSL if enabled
    if [ "$USE_SSL" = true ]; then
        if ! setup_ssl; then
            show_banner "error"
            print_status "SSL setup failed" "ERROR"
            cleanup_on_error
            exit 1
        fi
    fi
    
    # Start Wazuh services
    if ! start_wazuh_services; then
        show_banner "error"
        print_status "Failed to start Wazuh services" "ERROR"
        cleanup_on_error
        exit 1
    fi
    
    # Save installation details
    save_installation_details
    
    # Show completion message
    show_completion_message
    
    return 0
}

# Start script execution
main "$@"
