#!/bin/bash

# Enhanced Wazuh setup script with Docker support, improved network handling,
# and comprehensive domain/DNS management

# Enable strict error handling
set -e

# Variables
LOG_FILE="wazuh_setup.log"
START_TIME=$(date)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_VERSION="1.0.0"

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
INSTALL_TYPE=""
DOMAIN=""
EMAIL=""
USE_SSL=false
PUBLIC_IP=""
ZEROTIER_IP=""
ZEROTIER_NETWORK_ID=""
USE_CLOUDFLARE=false

# Colors for output
COLOR_INFO="\e[34m"     # Blue
COLOR_SUCCESS="\e[32m"  # Green
COLOR_ERROR="\e[31m"    # Red
COLOR_WARNING="\e[33m"  # Yellow
COLOR_RESET="\e[0m"     # Reset
COLOR_CYAN="\e[36m"     # Cyan for highlights
COLOR_MAGENTA="\e[35m"  # Magenta for special messages

# Function to show main banner
show_main_banner() {
    clear
    cat << "EOF"
 __          __     _______ _    _ _    _ 
 \ \        / /\   |__   __| |  | | |  | |
  \ \  /\  / /  \     | |  | |__| | |__| |
   \ \/  \/ / /\ \    | |  |  __  |  __  |
    \  /\  / ____ \   | |  | |  | | |  | |
     \/  \/_/    \_\  |_|  |_|  |_|_|  |_|
                                          
   Docker Installation & Setup Wizard
EOF
    echo -e "\n${COLOR_CYAN}Version: $SCRIPT_VERSION${COLOR_RESET}"
    echo -e "${COLOR_CYAN}Started at: $START_TIME${COLOR_RESET}"
    echo -e "${COLOR_CYAN}----------------------------------------${COLOR_RESET}\n"
}

# Function to show error banner
show_error_banner() {
    local error_message="$1"
    clear
    cat << "EOF"
  _____ ____  ____   ___  ____  
 | ____|  _ \|  _ \ / _ \|  _ \ 
 |  _| | |_) | |_) | | | | |_) |
 | |___|  _ <|  _ <| |_| |  _ < 
 |_____|_| \_\_| \_\\___/|_| \_\
                                
EOF
    echo -e "\n${COLOR_ERROR}$error_message${COLOR_RESET}\n"
}

# Function to show success banner
show_success_banner() {
    clear
    cat << "EOF"
  ____  _   _  ____ ____ _____ ____ ____  
 / ___|| | | |/ ___/ ___| ____/ ___/ ___| 
 \___ \| | | | |  | |   |  _| \___ \___ \ 
  ___) | |_| | |__| |___| |___ ___) |__) |
 |____/ \___/ \____\____|_____|____/____/ 
                                          
EOF
    echo -e "\n${COLOR_SUCCESS}Installation Completed Successfully!${COLOR_RESET}\n"
}

# Enhanced progress bar with spinner
show_progress() {
    local current=$1
    local total=$2
    local width=50
    local percentage=$((current * 100 / total))
    local completed=$((width * current / total))
    local remaining=$((width - completed))
    local spinner=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
    local spin_idx=$((current % ${#spinner[@]}))
    
    printf "\r${COLOR_CYAN}[${spinner[$spin_idx]}] Progress: [%${completed}s%${remaining}s] %d%%${COLOR_RESET}" \
           "$(printf '#%.0s' $(seq 1 $completed))" \
           "$(printf ' %.0s' $(seq 1 $remaining))" \
           "$percentage"
}

# Function to get user input with validation
get_user_input() {
    local prompt="$1"
    local validate_func="$2"
    local value=""
    local valid=false
    
    while [ "$valid" = false ]; do
        echo -e "${COLOR_CYAN}$prompt${COLOR_RESET}"
        read -r value
        
        if [ -n "$validate_func" ]; then
            if $validate_func "$value"; then
                valid=true
            else
                echo -e "${COLOR_ERROR}Invalid input. Please try again.${COLOR_RESET}"
            fi
        else
            valid=true
        fi
    done
    
    echo "$value"
}

# Validation functions
validate_domain() {
    local domain="$1"
    local domain_regex="^([a-zA-Z0-9][a-zA-Z0-9-]{0,61}[a-zA-Z0-9]\.)+[a-zA-Z]{2,}$"
    
    if [[ $domain =~ $domain_regex ]]; then
        return 0
    fi
    echo -e "${COLOR_ERROR}Invalid domain format. Example: wazuh.yourdomain.com${COLOR_RESET}"
    return 1
}

validate_email() {
    local email="$1"
    local email_regex="^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$"
    
    if [[ $email =~ $email_regex ]]; then
        return 0
    fi
    echo -e "${COLOR_ERROR}Invalid email format. Example: user@domain.com${COLOR_RESET}"
    return 1
}

validate_zerotier_id() {
    local id="$1"
    local id_regex="^[0-9a-fA-F]{16}$"
    
    if [[ $id =~ $id_regex ]]; then
        return 0
    fi
    echo -e "${COLOR_ERROR}Invalid ZeroTier Network ID. Should be 16 hexadecimal characters.${COLOR_RESET}"
    return 1
}

# Function to collect user inputs
collect_user_inputs() {
    show_main_banner
    echo -e "${COLOR_MAGENTA}Welcome to the Wazuh Installation Wizard!${COLOR_RESET}\n"
    echo -e "Please provide the following information:\n"
    
    # Get domain
    DOMAIN=$(get_user_input "Enter your domain (e.g., wazuh.yourdomain.com):" validate_domain)
    
    # Get email
    EMAIL=$(get_user_input "Enter your email address:" validate_email)
    
    # Get ZeroTier Network ID
    ZEROTIER_NETWORK_ID=$(get_user_input "Enter your ZeroTier Network ID:" validate_zerotier_id)
    
    # SSL preference
    while true; do
        read -p "Do you want to enable SSL? (y/n): " ssl_choice
        case $ssl_choice in
            [Yy]* ) USE_SSL=true; break;;
            [Nn]* ) USE_SSL=false; break;;
            * ) echo "Please answer yes or no.";;
        esac
    done
    
    # Cloudflare usage
    while true; do
        read -p "Are you using Cloudflare? (y/n): " cf_choice
        case $cf_choice in
            [Yy]* ) USE_CLOUDFLARE=true; break;;
            [Nn]* ) USE_CLOUDFLARE=false; break;;
            * ) echo "Please answer yes or no.";;
        esac
    done
    
    # Show summary and confirm
    echo -e "\n${COLOR_CYAN}Configuration Summary:${COLOR_RESET}"
    echo "----------------------------------------"
    echo "Domain: $DOMAIN"
    echo "Email: $EMAIL"
    echo "ZeroTier Network ID: $ZEROTIER_NETWORK_ID"
    echo "SSL Enabled: $USE_SSL"
    echo "Using Cloudflare: $USE_CLOUDFLARE"
    echo "----------------------------------------"
    
    while true; do
        read -p "Is this information correct? (y/n): " confirm
        case $confirm in
            [Yy]* ) return 0;;
            [Nn]* ) return 1;;
            * ) echo "Please answer yes or no.";;
        esac
    done
}

# Main function
main() {
    # Check if running as root
    if [ "$EUID" -ne 0 ]; then
        show_error_banner "This script must be run as root"
        exit 1
    fi
    
    # Collect user inputs
    if ! collect_user_inputs; then
        show_error_banner "Configuration cancelled by user"
        exit 1
    fi
    
    # Start installation process
    show_main_banner
    
    # Continue with installation steps...
    # (This will be implemented in the next parts)
    
    return 0
}

# Start script execution
main

# Function to detect and validate network configuration
setup_network() {
    update_progress "Network Configuration"
    print_status "Setting up network configuration..." "INFO"
    
    # Check internet connectivity first
    if ! check_internet_connectivity; then
        show_error_banner "No internet connection detected"
        return 1
    fi
    
    # Detect public IP
    print_status "Detecting public IP address..." "INFO"
    local ip_services=(
        "https://ifconfig.me"
        "https://api.ipify.org"
        "https://icanhazip.com"
        "https://ipecho.net/plain"
    )
    
    for service in "${ip_services[@]}"; do
        PUBLIC_IP=$(curl -s "$service")
        if validate_ip "$PUBLIC_IP"; then
            print_status "Public IP detected: $PUBLIC_IP" "SUCCESS"
            break
        fi
    done
    
    if ! validate_ip "$PUBLIC_IP"; then
        show_error_banner "Failed to detect public IP"
        return 1
    fi
    
    # Setup ZeroTier
    print_status "Setting up ZeroTier network..." "INFO"
    if ! setup_zerotier_network; then
        show_error_banner "ZeroTier setup failed"
        return 1
    fi
    
    return 0
}

# Function to setup ZeroTier network
setup_zerotier_network() {
    print_status "Installing and configuring ZeroTier..." "INFO"
    
    # Install ZeroTier if not present
    if ! command -v zerotier-cli &>/dev/null; then
        print_status "Installing ZeroTier..." "INFO"
        curl -s https://install.zerotier.com | bash || {
            print_status "Failed to install ZeroTier" "ERROR"
            return 1
        }
    fi
    
    # Join ZeroTier network
    print_status "Joining ZeroTier network: $ZEROTIER_NETWORK_ID" "INFO"
    zerotier-cli join "$ZEROTIER_NETWORK_ID" || {
        print_status "Failed to join ZeroTier network" "ERROR"
        return 1
    }
    
    # Wait for network connection
    print_status "Waiting for ZeroTier connection..." "INFO"
    local max_attempts=30
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        show_progress $attempt $max_attempts
        
        ZEROTIER_IP=$(zerotier-cli listnetworks | grep "$ZEROTIER_NETWORK_ID" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+')
        if [ -n "$ZEROTIER_IP" ]; then
            echo "" # New line after progress bar
            print_status "ZeroTier IP obtained: $ZEROTIER_IP" "SUCCESS"
            return 0
        fi
        
        sleep 2
        ((attempt++))
    done
    
    echo "" # New line after progress bar
    print_status "Failed to obtain ZeroTier IP" "ERROR"
    return 1
}

# Function to setup Docker environment
setup_docker() {
    update_progress "Docker Installation"
    print_status "Setting up Docker environment..." "INFO"
    
    # Show Docker installation banner
    cat << "EOF"
    ____             _             
   |  _ \  ___   ___| | _____ _ __ 
   | | | |/ _ \ / __| |/ / _ \ '__|
   | |_| | (_) | (__|   <  __/ |   
   |____/ \___/ \___|_|\_\___|_|   
                                   
EOF
    
    # Check if Docker is already installed
    if command -v docker &>/dev/null; then
        print_status "Docker is already installed" "INFO"
        docker_version=$(docker --version | cut -d ' ' -f3 | tr -d ',')
        print_status "Current Docker version: $docker_version" "INFO"
        
        # Verify Docker daemon is running
        if ! systemctl is-active --quiet docker; then
            print_status "Starting Docker daemon..." "INFO"
            systemctl start docker
            systemctl enable docker
        fi
    else
        # Install Docker
        print_status "Installing Docker..." "INFO"
        
        # Install prerequisites
        apt-get update
        apt-get install -y \
            apt-transport-https \
            ca-certificates \
            curl \
            gnupg \
            lsb-release
        
        # Add Docker's official GPG key
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
        
        # Add Docker repository
        echo \
            "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
            $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
        
        # Install Docker packages
        apt-get update
        apt-get install -y docker-ce docker-ce-cli containerd.io
        
        # Start and enable Docker service
        systemctl start docker
        systemctl enable docker
    fi
    
    # Install Docker Compose
    if ! command -v docker-compose &>/dev/null; then
        print_status "Installing Docker Compose..." "INFO"
        curl -L "https://github.com/docker/compose/releases/download/v${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        chmod +x /usr/local/bin/docker-compose
    fi
    
    # Verify Docker installation
    if docker --version && docker-compose --version; then
        print_status "Docker environment setup completed successfully" "SUCCESS"
        
        # Show versions
        echo -e "\nInstalled versions:"
        echo "----------------------------------------"
        docker --version
        docker-compose --version
        echo "----------------------------------------"
        
        return 0
    else
        show_error_banner "Docker installation failed"
        return 1
    fi
}

# Function to verify Docker setup
verify_docker_setup() {
    print_status "Verifying Docker setup..." "INFO"
    
    # Check Docker daemon
    if ! docker info &>/dev/null; then
        print_status "Docker daemon is not running" "ERROR"
        return 1
    fi
    
    # Check Docker Compose
    if ! docker-compose version &>/dev/null; then
        print_status "Docker Compose is not working properly" "ERROR"
        return 1
    fi
    
    # Create Docker network if it doesn't exist
    if ! docker network inspect wazuh-network &>/dev/null; then
        print_status "Creating Docker network: wazuh-network" "INFO"
        if ! docker network create wazuh-network; then
            print_status "Failed to create Docker network" "ERROR"
            return 1
        fi
    fi
    
    print_status "Docker setup verified successfully" "SUCCESS"
    return 0
}

# Update main function to include new components
main() {
    # Previous main function content...
    
    # Setup network
    if ! setup_network; then
        show_error_banner "Network setup failed"
        exit 1
    fi
    
    # Setup Docker
    if ! setup_docker; then
        show_error_banner "Docker setup failed"
        exit 1
    fi
    
    # Verify Docker setup
    if ! verify_docker_setup; then
        show_error_banner "Docker verification failed"
        exit 1
    fi
    
    # Continue with next steps...
    return 0
}

# Function to setup Wazuh environment
setup_wazuh() {
    update_progress "Wazuh Installation"
    
    # Show Wazuh installation banner
    cat << "EOF"
 _    _                    _     
| |  | |                  | |    
| |  | | __ _ _____   _  | |__  
| |/\| |/ _` |_  / | | | | '_ \ 
\  /\  / (_| |/ /| |_| | | | | |
 \/  \/ \__,_/___|\__,_| |_| |_|
                                
EOF
    
    print_status "Setting up Wazuh environment..." "INFO"
    
    # Create installation directory
    local install_dir="/opt/wazuh-docker"
    mkdir -p "$install_dir"
    cd "$install_dir"
    
    # Generate random passwords for services
    local elastic_pass=$(openssl rand -base64 32)
    local indexer_pass=$(openssl rand -base64 32)
    local wazuh_pass=$(openssl rand -base64 32)
    
    # Save passwords to a secure file
    cat > "$install_dir/.env" << EOF
ELASTIC_PASSWORD=$elastic_pass
INDEXER_PASSWORD=$indexer_pass
WAZUH_API_PASSWORD=$wazuh_pass
EOF
    chmod 600 "$install_dir/.env"
    
    # Generate Docker Compose configuration
    if ! generate_docker_compose; then
        return 1
    fi
    
    # Generate NGINX configuration
    if ! generate_nginx_config; then
        return 1
    fi
    
    # Setup SSL if enabled
    if [ "$USE_SSL" = true ]; then
        if ! setup_ssl; then
            return 1
        fi
    fi
    
    return 0
}

# Function to generate Docker Compose configuration
generate_docker_compose() {
    print_status "Generating Docker Compose configuration..." "INFO"
    
    cat > "docker-compose.yml" << EOF
version: '3.8'

x-logging: &logging
  logging:
    driver: "json-file"
    options:
      max-size: "50m"
      max-file: "5"

services:
  wazuh.manager:
    <<: *logging
    image: wazuh/wazuh-manager:latest
    hostname: wazuh.manager
    restart: unless-stopped
    ports:
      - "1514:1514"
      - "1515:1515"
      - "514:514/udp"
      - "55000:55000"
    environment:
      - ELASTICSEARCH_URL=https://elasticsearch:9200
      - ELASTIC_USERNAME=elastic
      - ELASTIC_PASSWORD=\${ELASTIC_PASSWORD}
      - FILEBEAT_SSL_VERIFICATION_MODE=full
      - INDEXER_URL=https://wazuh.indexer:9200
      - INDEXER_USERNAME=admin
      - INDEXER_PASSWORD=\${INDEXER_PASSWORD}
      - WAZUH_API_USER=wazuh-wui
      - WAZUH_API_PASSWORD=\${WAZUH_API_PASSWORD}
    volumes:
      - wazuh_api_configuration:/var/ossec/api/configuration
      - wazuh_etc:/var/ossec/etc
      - wazuh_logs:/var/ossec/logs
      - wazuh_queue:/var/ossec/queue
      - wazuh_var_multigroups:/var/ossec/var/multigroups
      - wazuh_integrations:/var/ossec/integrations
      - wazuh_active_response:/var/ossec/active-response/bin
      - wazuh_agentless:/var/ossec/agentless
      - wazuh_wodles:/var/ossec/wodles
      - filebeat_etc:/etc/filebeat
      - filebeat_var:/var/lib/filebeat
    networks:
      - wazuh-network
    healthcheck:
      test: ["CMD", "/var/ossec/bin/wazuh-control", "status"]
      interval: 30s
      timeout: 10s
      retries: 5

  nginx:
    <<: *logging
    image: nginx:latest
    hostname: nginx
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf:ro
      - ./certs:/etc/nginx/certs:ro
    depends_on:
      - wazuh.manager
    networks:
      - wazuh-network
    healthcheck:
      test: ["CMD", "nginx", "-t"]
      interval: 30s
      timeout: 10s
      retries: 5

networks:
  wazuh-network:
    driver: bridge

volumes:
  wazuh_api_configuration:
  wazuh_etc:
  wazuh_logs:
  wazuh_queue:
  wazuh_var_multigroups:
  wazuh_integrations:
  wazuh_active_response:
  wazuh_agentless:
  wazuh_wodles:
  filebeat_etc:
  filebeat_var:
EOF
    
    print_status "Docker Compose configuration generated" "SUCCESS"
    return 0
}

# Function to generate NGINX configuration
generate_nginx_config() {
    print_status "Generating NGINX configuration..." "INFO"
    
    cat > "nginx.conf" << EOF
user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log warn;
pid /var/run/nginx.pid;

events {
    worker_connections 1024;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;
    
    log_format main '\$remote_addr - \$remote_user [\$time_local] "\$request" '
                    '\$status \$body_bytes_sent "\$http_referer" '
                    '"\$http_user_agent" "\$http_x_forwarded_for"';
    
    access_log /var/log/nginx/access.log main;
    
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;
    
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers on;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384;
    
    server {
        listen 80;
        server_name ${DOMAIN};
        
        location / {
            return 301 https://\$host\$request_uri;
        }
    }
    
    server {
        listen 443 ssl http2;
        server_name ${DOMAIN};
        
        ssl_certificate /etc/nginx/certs/fullchain.pem;
        ssl_certificate_key /etc/nginx/certs/privkey.pem;
        
        location / {
            proxy_pass http://wazuh.manager:55000;
            proxy_http_version 1.1;
            proxy_set_header Upgrade \$http_upgrade;
            proxy_set_header Connection 'upgrade';
            proxy_set_header Host \$host;
            proxy_cache_bypass \$http_upgrade;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;
            
            # Security headers
            add_header X-Frame-Options "SAMEORIGIN" always;
            add_header X-XSS-Protection "1; mode=block" always;
            add_header X-Content-Type-Options "nosniff" always;
            add_header Referrer-Policy "no-referrer-when-downgrade" always;
            add_header Content-Security-Policy "default-src 'self' http: https: data: blob: 'unsafe-inline'" always;
            add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
        }
    }
}
EOF
    
    print_status "NGINX configuration generated" "SUCCESS"
    return 0
}

# Function to start Wazuh services
start_wazuh_services() {
    update_progress "Starting Services"
    print_status "Starting Wazuh services..." "INFO"
    
    # Pull Docker images
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
    
    # Wait for services to be healthy
    local services=("wazuh.manager" "nginx")
    local max_attempts=30
    local attempt=1
    
    for service in "${services[@]}"; do
        print_status "Waiting for $service to be ready..." "INFO"
        while [ $attempt -le $max_attempts ]; do
            show_progress $attempt $max_attempts
            
            if docker-compose ps "$service" | grep -q "Up (healthy)"; then
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
        attempt=1
    done
    
    print_status "All services started successfully" "SUCCESS"
    return 0
}

# Update main function to include new components
main() {
    # Previous main function content...
    
    # Setup Wazuh
    if ! setup_wazuh; then
        show_error_banner "Wazuh setup failed"
        exit 1
    fi
    
    # Start services
    if ! start_wazuh_services; then
        show_error_banner "Failed to start Wazuh services"
        exit 1
    fi
    
    # Continue with next steps...
    return 0
}

# Function to verify complete installation
verify_complete_installation() {
    update_progress "Final Verification"
    
    # Show verification banner
    cat << "EOF"
 _    _           _ _   _     
| |  | |         (_) | | |    
| |__| | ___  ___ _| |_| |__  
|  __  |/ _ \/ __| | __| '_ \ 
| |  | |  __/\__ \ | |_| | | |
|_|  |_|\___||___/_|\__|_| |_|
                              
   Checking Installation...
EOF
    
    print_status "Performing final verification..." "INFO"
    
    local checks=(
        check_docker_status
        check_services_health
        check_network_connectivity
        check_ssl_configuration
        check_wazuh_api
    )
    
    local failed_checks=()
    local total_checks=${#checks[@]}
    local current_check=0
    
    for check in "${checks[@]}"; do
        ((current_check++))
        show_progress $current_check $total_checks
        
        if ! $check; then
            failed_checks+=("$check")
        fi
        sleep 1
    done
    
    echo "" # New line after progress bar
    
    if [ ${#failed_checks[@]} -eq 0 ]; then
        print_status "All verification checks passed" "SUCCESS"
        return 0
    else
        print_status "The following checks failed:" "ERROR"
        for check in "${failed_checks[@]}"; do
            echo "- ${check#check_}"
        done
        return 1
    fi
}

# Individual verification checks
check_docker_status() {
    print_status "Checking Docker status..." "INFO"
    if ! docker info &>/dev/null; then
        print_status "Docker is not running properly" "ERROR"
        return 1
    fi
    return 0
}

check_services_health() {
    print_status "Checking service health..." "INFO"
    local services=("wazuh.manager" "nginx")
    
    for service in "${services[@]}"; do
        if ! docker-compose ps "$service" | grep -q "Up (healthy)"; then
            print_status "Service $service is not healthy" "ERROR"
            return 1
        fi
    done
    return 0
}

check_network_connectivity() {
    print_status "Checking network connectivity..." "INFO"
    
    # Check ZeroTier connection
    if ! zerotier-cli listnetworks | grep -q "$ZEROTIER_NETWORK_ID"; then
        print_status "ZeroTier network connection failed" "ERROR"
        return 1
    fi
    
    # Check domain resolution
    if ! dig +short "$DOMAIN" | grep -q "$PUBLIC_IP"; then
        print_status "Domain resolution failed" "ERROR"
        return 1
    fi
    
    return 0
}

check_ssl_configuration() {
    print_status "Checking SSL configuration..." "INFO"
    if [ "$USE_SSL" = true ]; then
        if [ ! -f "/opt/wazuh-docker/certs/fullchain.pem" ] || [ ! -f "/opt/wazuh-docker/certs/privkey.pem" ]; then
            print_status "SSL certificates are missing" "ERROR"
            return 1
        fi
    fi
    return 0
}

check_wazuh_api() {
    print_status "Checking Wazuh API..." "INFO"
    local api_url="https://${DOMAIN}/version"
    if [ "$USE_SSL" = false ]; then
        api_url="http://${DOMAIN}/version"
    fi
    
    if ! curl -sk "$api_url" | grep -q "wazuh"; then
        print_status "Wazuh API is not responding" "ERROR"
        return 1
    fi
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
    show_success_banner
    
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

# Update main function with final components
main() {
    # Set up error handling
    trap 'cleanup_on_error $? $LINENO' ERR
    
    # Previous main function content...
    
    # Verify installation
    if ! verify_complete_installation; then
        show_error_banner "Installation verification failed"
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
