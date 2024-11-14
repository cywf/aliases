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

# Function to setup SSL
setup_ssl() {
    if [ "$USE_SSL" = false ]; then
        return 0
    fi
    
    print_status "Setting up SSL certificates..." "INFO"
    
    local cert_dir="/opt/wazuh-docker/certs"
    mkdir -p "$cert_dir"
    
    if [ "$USE_CLOUDFLARE" = true ]; then
        setup_cloudflare_ssl "$cert_dir"
    else
        setup_letsencrypt_ssl "$cert_dir"
    fi
    
    return $?
}

# Function to setup Let's Encrypt SSL
setup_letsencrypt_ssl() {
    local cert_dir="$1"
    
    print_status "Setting up Let's Encrypt SSL..." "INFO"
    
    # Install certbot if not present
    if ! command -v certbot &>/dev/null; then
        print_status "Installing certbot..." "INFO"
        apt-get update
        apt-get install -y certbot
    fi
    
    # Get certificate
    certbot certonly --standalone \
        --non-interactive \
        --agree-tos \
        --email "$EMAIL" \
        --domain "$DOMAIN" \
        --preferred-challenges http || {
        print_status "Failed to obtain SSL certificate" "ERROR"
        return 1
    }
    
    # Copy certificates to cert directory
    cp /etc/letsencrypt/live/"$DOMAIN"/fullchain.pem "$cert_dir/server.crt"
    cp /etc/letsencrypt/live/"$DOMAIN"/privkey.pem "$cert_dir/server.key"
    
    print_status "SSL certificates installed" "SUCCESS"
    return 0
}

# Function to start Wazuh services
start_wazuh_services() {
    print_status "Starting Wazuh services..." "INFO"
    
    cd /opt/wazuh-docker
    
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
    
    show_error_banner "Installation failed on line $error_line"
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
        show_error_banner "Prerequisites check failed"
        exit 1
    fi
    
    # Setup SSL if enabled
    if [ "$USE_SSL" = true ]; then
        if ! setup_ssl; then
            show_error_banner "SSL setup failed"
            cleanup_on_error
            exit 1
        fi
    fi
    
    # Start Wazuh services
    if ! start_wazuh_services; then
        show_error_banner "Failed to start Wazuh services"
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
