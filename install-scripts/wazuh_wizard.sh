#!/bin/bash

# Enhanced Wazuh setup script with Docker support, improved network handling,
# and comprehensive domain/DNS management

# Enable strict error handling
set -e

# Variables
LOG_FILE="wazuh_setup.log"
START_TIME=$(date)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Installation steps tracking
declare -a STEPS=(
    "Check Prerequisites"
    "Configure Network"
    "Setup Domain"
    "Install Docker"
    "Configure Services"
    "Start Containers"
    "Verify Installation"
)
TOTAL_STEPS=${#STEPS[@]}
CURRENT_STEP=0

# Configuration variables
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
COLOR_INFO="\e[34m"    # Blue
COLOR_SUCCESS="\e[32m" # Green
COLOR_ERROR="\e[31m"   # Red
COLOR_WARNING="\e[33m" # Yellow
COLOR_RESET="\e[0m"    # Reset

# Function to show ASCII banner
show_banner() {
    clear
    cat << "EOF"
 __          __              _     
 \ \        / /             | |    
  \ \  /\  / /_ _ _____   _| |__  
   \ \/  \/ / _` |_  / | | | '_ \ 
    \  /\  / (_| |/ /| |_| | | | |
     \/  \/ \__,_/___|\__,_|_| |_|
                                  
    Docker Installation Wizard
    
EOF
    echo "Version: 1.0.0"
    echo "Starting installation at: $START_TIME"
    echo "----------------------------------------"
    echo ""
}

# Function to show progress bar
show_progress() {
    local current=$1
    local total=$2
    local width=50
    local percentage=$((current * 100 / total))
    local completed=$((width * current / total))
    local remaining=$((width - completed))
    
    printf "\rProgress: [%${completed}s%${remaining}s] %d%%" \
           "$(printf '#%.0s' $(seq 1 $completed))" \
           "$(printf ' %.0s' $(seq 1 $remaining))" \
           "$percentage"
}

# Function to update progress
update_progress() {
    local step_name=$1
    ((CURRENT_STEP++))
    echo -e "\n\n${COLOR_INFO}Step $CURRENT_STEP/$TOTAL_STEPS: $step_name${COLOR_RESET}"
    show_progress $CURRENT_STEP $TOTAL_STEPS
    echo -e "\n"
}

# Function to print status messages with colors
print_status() {
    local message="$1"
    local type="$2"  # INFO, SUCCESS, ERROR, WARNING
    local color=""
    case "$type" in
        INFO)     color="$COLOR_INFO" ;;
        SUCCESS)  color="$COLOR_SUCCESS" ;;
        ERROR)    color="$COLOR_ERROR" ;;
        WARNING)  color="$COLOR_WARNING" ;;
        *)        color="$COLOR_RESET" ;;
    esac
    echo -e "${color}[$(date +"%Y-%m-%d %H:%M:%S")] $message${COLOR_RESET}"
    echo "[$(date +"%Y-%m-%d %H:%M:%S")] $message" >> "$LOG_FILE"
}

# Function to check internet connectivity
check_internet_connectivity() {
    print_status "Checking internet connectivity..." "INFO"
    
    local test_urls=(
        "google.com"
        "cloudflare.com"
        "github.com"
        "1.1.1.1"
    )
    
    for url in "${test_urls[@]}"; do
        if ping -c 1 -W 5 "$url" &>/dev/null; then
            print_status "Internet connectivity confirmed via $url" "SUCCESS"
            return 0
        fi
    done
    
    print_status "No internet connectivity detected. Please check your network connection." "ERROR"
    return 1
}

# Function to cleanup on error
cleanup() {
    local exit_code=$?
    local line_number=$1
    
    if [ $exit_code -ne 0 ]; then
        print_status "Error occurred on line $line_number" "ERROR"
        print_status "Cleaning up..." "INFO"
        
        # Stop any running containers
        if [ -f "/opt/wazuh-docker/docker-compose.yml" ]; then
            cd /opt/wazuh-docker
            docker-compose down -v &>/dev/null || true
        fi
        
        # Remove installation directory
        rm -rf /opt/wazuh-docker &>/dev/null || true
        
        print_status "Cleanup completed. Check $LOG_FILE for details." "INFO"
    fi
    
    exit $exit_code
}

# Function to validate prerequisites
check_prerequisites() {
    update_progress "${STEPS[0]}"
    print_status "Checking prerequisites..." "INFO"
    
    # Check required commands
    local required_commands=(
        "curl"
        "wget"
        "dig"
        "openssl"
    )
    
    local missing_commands=()
    
    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" &>/dev/null; then
            missing_commands+=("$cmd")
        fi
    done
    
    if [ ${#missing_commands[@]} -ne 0 ]; then
        print_status "Installing missing prerequisites: ${missing_commands[*]}" "INFO"
        apt-get update
        apt-get install -y "${missing_commands[@]}"
    fi
    
    print_status "All prerequisites satisfied" "SUCCESS"
    return 0
}

# Function to verify Docker services
verify_docker_services() {
    print_status "Verifying Docker services..." "INFO"
    
    local services=(
        "wazuh.manager"
        "nginx"
        "zerotier"
    )
    
    local failed_services=()
    
    for service in "${services[@]}"; do
        if ! docker-compose ps "$service" | grep -q "Up"; then
            failed_services+=("$service")
        fi
    done
    
    if [ ${#failed_services[@]} -eq 0 ]; then
        print_status "All services are running properly" "SUCCESS"
        return 0
    else
        print_status "The following services failed to start: ${failed_services[*]}" "ERROR"
        print_status "Check logs with: docker-compose logs ${failed_services[*]}" "INFO"
        return 1
    fi
}

# Set up error handling
trap 'cleanup ${LINENO}' ERR

# Start logging
exec 1> >(tee -a "$LOG_FILE") 2>&1

# Main execution starts here
show_banner
check_prerequisites

# Function to validate IP address
validate_ip() {
    local ip=$1
    local ip_regex='^([0-9]{1,3}\.){3}[0-9]{1,3}$'
    
    if [[ ! $ip =~ $ip_regex ]]; then
        return 1
    fi
    
    local IFS='.'
    read -ra ip_parts <<< "$ip"
    for part in "${ip_parts[@]}"; do
        if [ "$part" -gt 255 ] || [ "$part" -lt 0 ]; then
            return 1
        fi
    done
    
    return 0
}

# Function to validate ZeroTier network ID
validate_zerotier_network_id() {
    local network_id=$1
    local network_id_regex='^[0-9a-fA-F]{16}$'
    
    if [[ ! $network_id =~ $network_id_regex ]]; then
        return 1
    fi
    return 0
}

# Function to setup ZeroTier
setup_zerotier() {
    update_progress "Setting up ZeroTier"
    print_status "Configuring ZeroTier network..." "INFO"
    
    # Install ZeroTier if not present
    if ! command -v zerotier-cli &>/dev/null; then
        print_status "Installing ZeroTier..." "INFO"
        curl -s https://install.zerotier.com | bash || {
            print_status "Failed to install ZeroTier" "ERROR"
            return 1
        }
    fi
    
    # Get ZeroTier Network ID
    while true; do
        read -p "Enter your ZeroTier Network ID: " ZEROTIER_NETWORK_ID
        if validate_zerotier_network_id "$ZEROTIER_NETWORK_ID"; then
            break
        else
            print_status "Invalid ZeroTier Network ID. It should be 16 hexadecimal characters." "ERROR"
        fi
    done
    
    # Join network
    print_status "Joining ZeroTier network..." "INFO"
    zerotier-cli join "$ZEROTIER_NETWORK_ID"
    
    # Wait for network connection
    print_status "Waiting for ZeroTier connection..." "INFO"
    local max_attempts=30
    local attempt=1
    local connected=false
    
    while [ $attempt -le $max_attempts ]; do
        show_progress $attempt $max_attempts
        
        if ZEROTIER_IP=$(zerotier-cli listnetworks | grep "$ZEROTIER_NETWORK_ID" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+'); then
            connected=true
            break
        fi
        
        sleep 2
        ((attempt++))
    done
    echo ""  # New line after progress bar
    
    if [ "$connected" = true ]; then
        print_status "Successfully connected to ZeroTier network" "SUCCESS"
        print_status "ZeroTier IP: $ZEROTIER_IP" "INFO"
        return 0
    else
        print_status "Failed to connect to ZeroTier network" "ERROR"
        print_status "Please check your network ID and ensure the network allows this device" "INFO"
        return 1
    fi
}

# Enhanced function to detect and validate IP addresses
detect_server_ips() {
    update_progress "Detecting Network Configuration"
    print_status "Detecting server IP configurations..." "INFO"
    
    # Detect public IP using multiple services for reliability
    local public_ip_services=(
        "ifconfig.me"
        "icanhazip.com"
        "ipecho.net/plain"
        "api.ipify.org"
    )
    
    print_status "Detecting public IP address..." "INFO"
    for service in "${public_ip_services[@]}"; do
        PUBLIC_IP=$(curl -s "$service" 2>/dev/null)
        if validate_ip "$PUBLIC_IP"; then
            print_status "Public IP detected: $PUBLIC_IP" "SUCCESS"
            break
        fi
    done
    
    if [ -z "$PUBLIC_IP" ]; then
        print_status "Failed to detect public IP address." "ERROR"
        return 1
    fi
    
    # Setup ZeroTier network
    if ! setup_zerotier; then
        print_status "ZeroTier setup failed. Proceeding with public IP only." "WARNING"
    fi
    
    # Display network configuration summary
    echo ""
    print_status "Network Configuration Summary:" "INFO"
    echo "----------------------------------------"
    echo "Public IP: $PUBLIC_IP (Use this for DNS A record)"
    if [ -n "$ZEROTIER_IP" ]; then
        echo "ZeroTier IP: $ZEROTIER_IP (Will be used for internal access)"
    fi
    echo "----------------------------------------"
    
    return 0
}

# Enhanced function to configure domain and DNS
configure_domain() {
    update_progress "Configuring Domain"
    print_status "Beginning domain configuration..." "INFO"
    
    # Detect and display IP information first
    if ! detect_server_ips; then
        print_status "IP detection failed. Cannot proceed with domain configuration." "ERROR"
        return 1
    fi
    
    # Domain configuration
    while true; do
        read -p "Enter your domain name (e.g., wazuh.yourdomain.com): " DOMAIN
        if validate_domain "$DOMAIN"; then
            break
        else
            print_status "Invalid domain format. Please enter a valid domain name." "ERROR"
        fi
    done
    
    # Email configuration for SSL
    while true; do
        read -p "Enter your email address (for SSL certificates): " EMAIL
        if [[ "$EMAIL" =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]]; then
            break
        else
            print_status "Invalid email format. Please enter a valid email address." "ERROR"
        fi
    done
    
    # Cloudflare configuration
    read -p "Are you using Cloudflare? (y/n): " use_cloudflare
    if [[ $use_cloudflare =~ ^[Yy]$ ]]; then
        USE_CLOUDFLARE=true
        show_cloudflare_instructions
    else
        USE_CLOUDFLARE=false
        show_standard_dns_instructions
    fi
    
    # Wait for DNS configuration
    wait_for_dns_configuration
    
    return 0
}

# Function to show Cloudflare-specific instructions
show_cloudflare_instructions() {
    print_status "Cloudflare Configuration Instructions:" "INFO"
    cat << EOF

1. Login to your Cloudflare dashboard
2. Select your domain
3. Go to DNS settings
4. Add an A record:
   - Name: ${DOMAIN%%.*} (subdomain part)
   - IPv4 address: $PUBLIC_IP
   - Proxy status: DNS only (grey cloud)
   
5. SSL/TLS settings:
   - Set encryption mode to 'Full'
   - Enable 'Always Use HTTPS'
   
6. Network settings:
   - Enable WebSockets

EOF
}

# Function to show standard DNS instructions
show_standard_dns_instructions() {
    print_status "Standard DNS Configuration Instructions:" "INFO"
    cat << EOF

Add the following DNS record to your domain provider:
- Type: A
- Name: ${DOMAIN%%.*} (subdomain part)
- Value: $PUBLIC_IP
- TTL: 300 (or lowest available)

EOF
}

# Function to wait for DNS configuration
wait_for_dns_configuration() {
    local configured=false
    
    while [ "$configured" = false ]; do
        read -p "Have you configured the DNS records as instructed? (y/n): " dns_configured
        if [[ $dns_configured =~ ^[Yy]$ ]]; then
            print_status "Verifying DNS configuration..." "INFO"
            if check_dns_propagation "$DOMAIN" "$PUBLIC_IP"; then
                configured=true
            else
                print_status "DNS verification failed. Options:" "WARNING"
                echo "1. Wait longer for DNS propagation"
                echo "2. Verify your DNS settings"
                echo "3. Continue anyway (not recommended)"
                echo "4. Exit and start over"
                read -p "Choose an option (1-4): " dns_option
                case $dns_option in
                    1) print_status "Waiting 60 seconds before next check..." "INFO"
                       sleep 60
                       ;;
                    2) if [ "$USE_CLOUDFLARE" = true ]; then
                           show_cloudflare_instructions
                       else
                           show_standard_dns_instructions
                       fi
                       ;;
                    3) configured=true
                       print_status "Proceeding without DNS verification..." "WARNING"
                       ;;
                    4) print_status "Installation cancelled." "INFO"
                       exit 0
                       ;;
                    *) print_status "Invalid option. Please try again." "ERROR"
                       ;;
                esac
            fi
        elif [[ $dns_configured =~ ^[Nn]$ ]]; then
            if [ "$USE_CLOUDFLARE" = true ]; then
                show_cloudflare_instructions
            else
                show_standard_dns_instructions
            fi
        fi
    done
}

# Function to setup Docker environment
setup_docker() {
    update_progress "Installing Docker"
    print_status "Setting up Docker environment..." "INFO"
    
    # Check if Docker is already installed
    if command -v docker &> /dev/null; then
        print_status "Docker is already installed. Checking version..." "INFO"
        docker_version=$(docker --version | cut -d ' ' -f3 | tr -d ',')
        print_status "Current Docker version: $docker_version" "INFO"
    else
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
        
        # Install Docker
        apt-get update
        apt-get install -y docker-ce docker-ce-cli containerd.io
        
        # Start and enable Docker service
        systemctl start docker
        systemctl enable docker
    fi
    
    # Install Docker Compose
    if ! command -v docker-compose &> /dev/null; then
        print_status "Installing Docker Compose..." "INFO"
        curl -L "https://github.com/docker/compose/releases/download/v${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        chmod +x /usr/local/bin/docker-compose
    fi
    
    # Verify Docker installation
    if ! docker info &>/dev/null; then
        print_status "Docker installation failed or daemon not running" "ERROR"
        return 1
    fi
    
    # Create Docker network for Wazuh
    if ! docker network inspect wazuh-network &>/dev/null; then
        docker network create wazuh-network
    fi
    
    print_status "Docker environment setup completed successfully" "SUCCESS"
    return 0
}

# Function to generate enhanced Docker Compose configuration
generate_docker_compose() {
    update_progress "Generating Docker Configuration"
    print_status "Generating Docker Compose configuration..." "INFO"
    
    local compose_file="docker-compose.yml"
    
    cat > "$compose_file" << EOF
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
      - ELASTIC_PASSWORD=\${ELASTIC_PASSWORD:-changeme}
      - FILEBEAT_SSL_VERIFICATION_MODE=full
      - INDEXER_URL=https://wazuh.indexer:9200
      - INDEXER_USERNAME=admin
      - INDEXER_PASSWORD=\${INDEXER_PASSWORD:-SecretPassword}
      - WAZUH_API_USER=wazuh-wui
      - WAZUH_API_PASSWORD=\${WAZUH_API_PASSWORD:-MyS3cr3tP4ssw0rd}
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

  zerotier:
    <<: *logging
    image: zerotier/zerotier
    hostname: zerotier
    restart: unless-stopped
    devices:
      - /dev/net/tun:/dev/net/tun
    cap_add:
      - NET_ADMIN
      - SYS_ADMIN
    volumes:
      - zerotier_data:/var/lib/zerotier-one
    environment:
      - ZEROTIER_NETWORK_ID=\${ZEROTIER_NETWORK_ID}
    networks:
      - wazuh-network
    healthcheck:
      test: ["CMD", "zerotier-cli", "listnetworks"]
      interval: 30s
      timeout: 10s
      retries: 5

networks:
  wazuh-network:
    name: wazuh-network
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
  zerotier_data:
EOF
    
    print_status "Docker Compose configuration generated successfully" "SUCCESS"
    
    # Verify the configuration
    if ! docker-compose config -q; then
        print_status "Docker Compose configuration validation failed" "ERROR"
        return 1
    fi
    
    return 0
}

# Function to monitor service startup
monitor_service_startup() {
    local service=$1
    local max_attempts=30
    local attempt=1
    
    print_status "Waiting for $service to be ready..." "INFO"
    
    while [ $attempt -le $max_attempts ]; do
        show_progress $attempt $max_attempts
        
        if docker-compose ps "$service" | grep -q "Up (healthy)"; then
            echo ""  # New line after progress bar
            print_status "$service is ready" "SUCCESS"
            return 0
        fi
        
        sleep 2
        ((attempt++))
    done
    
    echo ""  # New line after progress bar
    print_status "$service failed to start properly" "ERROR"
    return 1
}

# Function to setup Docker-based Wazuh installation
setup_docker_wazuh() {
    update_progress "Setting up Wazuh"
    print_status "Setting up Docker-based Wazuh installation..." "INFO"
    
    # Create project directory
    local install_dir="/opt/wazuh-docker"
    mkdir -p "$install_dir"
    cd "$install_dir"
    
    # Generate configurations
    if ! generate_docker_compose; then
        return 1
    fi
    
    if ! generate_nginx_config "$DOMAIN" "$USE_SSL"; then
        return 1
    fi
    
    # Setup SSL if enabled
    if [ "$USE_SSL" = true ]; then
        if ! setup_ssl "$DOMAIN" "$EMAIL"; then
            return 1
        fi
    fi
    
    # Generate secure environment file
    if ! generate_env_file; then
        return 1
    fi
    
    # Start the containers
    print_status "Starting Wazuh containers..." "INFO"
    if ! docker-compose up -d; then
        print_status "Failed to start Wazuh containers" "ERROR"
        return 1
    fi
    
    # Monitor service startup
    local services=("wazuh.manager" "nginx" "zerotier")
    for service in "${services[@]}"; do
        if ! monitor_service_startup "$service"; then
            print_status "Service startup monitoring failed" "ERROR"
            return 1
        fi
    done
    
    print_status "Wazuh installation completed successfully" "SUCCESS"
    return 0
}

# Function to setup SSL certificates
setup_ssl() {
    local domain="$1"
    local email="$2"
    
    update_progress "Setting up SSL"
    print_status "Setting up SSL certificates..." "INFO"
    
    # Create certificates directory
    mkdir -p certs
    
    if [ "$USE_CLOUDFLARE" = true ]; then
        setup_ssl_cloudflare "$domain"
    else
        setup_ssl_letsencrypt "$domain" "$email"
    fi
}

# Function to setup SSL with Cloudflare
setup_ssl_cloudflare() {
    local domain="$1"
    print_status "Generating self-signed certificate for Cloudflare..." "INFO"
    
    # Generate private key
    openssl genrsa -out certs/privkey.pem 2048
    
    # Generate CSR
    openssl req -new -key certs/privkey.pem -out certs/csr.pem -subj "/CN=${domain}"
    
    # Generate certificate
    openssl x509 -req -days 365 -in certs/csr.pem -signkey certs/privkey.pem -out certs/fullchain.pem
    
    if [ -f certs/fullchain.pem ] && [ -f certs/privkey.pem ]; then
        print_status "SSL certificates generated successfully" "SUCCESS"
        chmod 644 certs/fullchain.pem
        chmod 600 certs/privkey.pem
        return 0
    else
        print_status "Failed to generate SSL certificates" "ERROR"
        return 1
    fi
}

# Function to setup SSL with Let's Encrypt
setup_ssl_letsencrypt() {
    local domain="$1"
    local email="$2"
    
    print_status "Setting up Let's Encrypt certificates..." "INFO"
    
    # Install certbot if not present
    if ! command -v certbot &>/dev/null; then
        print_status "Installing certbot..." "INFO"
        apt-get update
        apt-get install -y certbot
    fi
    
    # Stop nginx if running
    docker-compose stop nginx 2>/dev/null || true
    
    # Get certificate
    if certbot certonly --standalone --preferred-challenges http \
        -d "$domain" --email "$email" --agree-tos --non-interactive; then
        
        # Copy certificates to nginx certs directory
        cp /etc/letsencrypt/live/$domain/fullchain.pem certs/
        cp /etc/letsencrypt/live/$domain/privkey.pem certs/
        
        chmod 644 certs/fullchain.pem
        chmod 600 certs/privkey.pem
        
        # Setup auto-renewal
        setup_ssl_renewal
        
        print_status "SSL certificates obtained successfully" "SUCCESS"
        return 0
    else
        print_status "Failed to obtain SSL certificates" "ERROR"
        return 1
    fi
}

# Function to setup SSL auto-renewal
setup_ssl_renewal() {
    print_status "Setting up SSL auto-renewal..." "INFO"
    
    # Create renewal script
    cat > ssl-renewal.sh << 'EOF'
#!/bin/bash
certbot renew --quiet
docker-compose restart nginx
EOF
    
    chmod +x ssl-renewal.sh
    
    # Add to crontab
    (crontab -l 2>/dev/null | grep -v "ssl-renewal.sh"; echo "0 12 * * * $(pwd)/ssl-renewal.sh") | crontab -
    
    print_status "SSL auto-renewal configured" "SUCCESS"
}

# Function to display installation summary
display_installation_summary() {
    local install_dir="$1"
    
    clear
    cat << "EOF"
 _____ _           _ _   
|_   _| |         | | |  
  | | | |__   __ _| | |_ 
  | | | '_ \ / _` | | __|
  | | | | | | (_| | | |_ 
  \_/ |_| |_|\__,_|_|\__|
EOF
    
    echo -e "\nInstallation completed successfully!\n"
    
    print_status "Installation Summary:" "INFO"
    echo "----------------------------------------"
    echo "Installation Directory: $install_dir"
    echo "Domain: $DOMAIN"
    if [ "$USE_SSL" = true ]; then
        echo "SSL: Enabled"
        if [ "$USE_CLOUDFLARE" = true ]; then
            echo "SSL Provider: Cloudflare"
        else
            echo "SSL Provider: Let's Encrypt"
        fi
    else
        echo "SSL: Disabled"
    fi
    echo "ZeroTier Network ID: $ZEROTIER_NETWORK_ID"
    echo "----------------------------------------"
    
    print_status "Access Information:" "INFO"
    if [ "$USE_SSL" = true ]; then
        echo "Wazuh Dashboard: https://$DOMAIN"
    else
        echo "Wazuh Dashboard: http://$DOMAIN"
    fi
    echo "Default credentials: admin / admin"
    echo "----------------------------------------"
    
    print_status "Important Notes:" "WARNING"
    echo "1. Change the default password after first login"
    echo "2. Configure your firewall to allow required ports"
    echo "3. Backup the installation directory regularly"
    echo "----------------------------------------"
    
    print_status "Useful Commands:" "INFO"
    echo "- View logs: docker-compose logs -f"
    echo "- Restart services: docker-compose restart"
    echo "- Stop services: docker-compose down"
    echo "- Start services: docker-compose up -d"
    echo "----------------------------------------"
}

# Function to verify installation
verify_installation() {
    update_progress "Verifying Installation"
    print_status "Performing final verification..." "INFO"
    
    local checks=(
        "Docker daemon is running"
        "All containers are healthy"
        "NGINX is configured properly"
        "SSL certificates are valid"
        "ZeroTier connection is active"
    )
    
    local failed_checks=()
    
    # Check Docker daemon
    if ! docker info &>/dev/null; then
        failed_checks+=("Docker daemon is not running")
    fi
    
    # Check container health
    if ! docker-compose ps | grep -q "Up (healthy)"; then
        failed_checks+=("Some containers are not healthy")
    fi
    
    # Check NGINX configuration
    if ! docker-compose exec nginx nginx -t &>/dev/null; then
        failed_checks+=("NGINX configuration is invalid")
    fi
    
    # Check SSL certificates if enabled
    if [ "$USE_SSL" = true ]; then
        if [ ! -f "certs/fullchain.pem" ] || [ ! -f "certs/privkey.pem" ]; then
            failed_checks+=("SSL certificates are missing")
        fi
    fi
    
    # Check ZeroTier connection
    if ! zerotier-cli listnetworks | grep -q "$ZEROTIER_NETWORK_ID"; then
        failed_checks+=("ZeroTier connection is not active")
    fi
    
    if [ ${#failed_checks[@]} -eq 0 ]; then
        print_status "All checks passed successfully" "SUCCESS"
        return 0
    else
        print_status "The following checks failed:" "ERROR"
        for check in "${failed_checks[@]}"; do
            echo "- $check"
        done
        return 1
    fi
}

# Function to save installation config
save_installation_config() {
    local config_file="$1/installation_config.json"
    
    cat > "$config_file" << EOF
{
    "installation_date": "$(date)",
    "domain": "$DOMAIN",
    "use_ssl": $USE_SSL,
    "use_cloudflare": $USE_CLOUDFLARE,
    "zerotier_network_id": "$ZEROTIER_NETWORK_ID",
    "public_ip": "$PUBLIC_IP",
    "zerotier_ip": "$ZEROTIER_IP",
    "docker_compose_version": "$DOCKER_COMPOSE_VERSION"
}
EOF
    
    chmod 600 "$config_file"
    print_status "Installation configuration saved" "SUCCESS"
}
