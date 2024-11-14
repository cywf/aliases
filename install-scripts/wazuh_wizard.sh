#!/bin/bash

# Enhanced Wazuh setup script with Docker support, improved network handling,
# and comprehensive domain/DNS management

# Enable strict error handling
set -e

# Variables
LOG_FILE="wazuh_setup.log"
START_TIME=$(date)
step_counter=1
MAX_RETRIES=3
TIMEOUT_BETWEEN_RETRIES=5
DOCKER_COMPOSE_VERSION="2.21.0"

# Installation type (will be set by user choice)
INSTALL_TYPE=""

# Network-related variables
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

# Function to display headers
display_header() {
    clear
    echo "############################################################"
    echo "# Step $step_counter: $1"
    echo "############################################################"
    echo ""
    ((step_counter++))
}

# Function to detect and validate IP addresses
detect_server_ips() {
    print_status "Detecting server IP configurations..." "INFO"
    
    # Detect public IP using multiple services for reliability
    local public_ip_services=(
        "ifconfig.me"
        "icanhazip.com"
        "ipecho.net/plain"
        "api.ipify.org"
    )
    
    for service in "${public_ip_services[@]}"; do
        PUBLIC_IP=$(curl -s "$service" 2>/dev/null)
        if [[ -n "$PUBLIC_IP" && "$PUBLIC_IP" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            break
        fi
    done
    
    if [ -z "$PUBLIC_IP" ]; then
        print_status "Failed to detect public IP address." "ERROR"
        return 1
    fi
    
    print_status "Public IP detected: $PUBLIC_IP" "SUCCESS"
    
    # Check for ZeroTier installation and configuration
    if command -v zerotier-cli >/dev/null 2>&1; then
        if systemctl is-active --quiet zerotier-one; then
            ZEROTIER_IP=$(zerotier-cli listnetworks | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+')
            if [ -n "$ZEROTIER_IP" ]; then
                print_status "ZeroTier IP detected: $ZEROTIER_IP" "SUCCESS"
            else
                print_status "ZeroTier is installed but no IP assigned yet." "WARNING"
            fi
        else
            print_status "ZeroTier service is not running." "WARNING"
        fi
    else
        print_status "ZeroTier is not installed yet." "INFO"
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

# Function to verify network connectivity
verify_network_setup() {
    print_status "Verifying network configuration..." "INFO"
    
    # Check public IP connectivity
    if ! curl -s --connect-timeout 5 "http://$PUBLIC_IP" &>/dev/null; then
        print_status "Warning: Public IP might not be accessible externally" "WARNING"
        print_status "Please ensure your firewall allows incoming connections" "INFO"
    fi
    
    # Check ZeroTier connectivity if configured
    if [ -n "$ZEROTIER_IP" ]; then
        if ! ping -c 1 -W 5 "$ZEROTIER_IP" &>/dev/null; then
            print_status "Warning: ZeroTier network might not be properly configured" "WARNING"
            
            # Attempt to fix common ZeroTier issues
            print_status "Attempting to fix ZeroTier configuration..." "INFO"
            systemctl restart zerotier-one
            sleep 5
            
            if [ -n "$ZEROTIER_NETWORK_ID" ]; then
                zerotier-cli join "$ZEROTIER_NETWORK_ID"
                sleep 5
                
                # Verify again after fix attempt
                if ! ping -c 1 -W 5 "$ZEROTIER_IP" &>/dev/null; then
                    print_status "ZeroTier network is still not responding properly" "ERROR"
                    print_status "Please check your ZeroTier configuration manually" "INFO"
                    return 1
                fi
            fi
        fi
    fi
    
    return 0
}

# Function to validate domain
validate_domain() {
    local domain="$1"
    if [[ ! "$domain" =~ ^[a-zA-Z0-9][a-zA-Z0-9-]{1,61}[a-zA-Z0-9]\.[a-zA-Z]{2,}$ ]]; then
        return 1
    fi
    return 0
}

# Function to check DNS propagation
check_dns_propagation() {
    local domain="$1"
    local expected_ip="$2"
    local max_attempts=5
    local attempt=1
    
    print_status "Checking DNS propagation for $domain..." "INFO"
    
    while [ $attempt -le $max_attempts ]; do
        print_status "Attempt $attempt of $max_attempts..." "INFO"
        
        # Try multiple DNS resolvers
        local resolvers=("1.1.1.1" "8.8.8.8" "9.9.9.9")
        local resolved_ip=""
        
        for resolver in "${resolvers[@]}"; do
            resolved_ip=$(dig +short "@$resolver" "$domain" A | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' | head -n1)
            if [ -n "$resolved_ip" ]; then
                break
            fi
        done
        
        if [ -n "$resolved_ip" ]; then
            if [ "$resolved_ip" = "$expected_ip" ]; then
                print_status "DNS propagation confirmed! Domain resolves to correct IP." "SUCCESS"
                return 0
            else
                print_status "Domain resolves to $resolved_ip (expected: $expected_ip)" "WARNING"
            fi
        else
            print_status "Domain not resolving yet..." "WARNING"
        fi
        
        if [ $attempt -lt $max_attempts ]; then
            print_status "Waiting 30 seconds before next check..." "INFO"
            sleep 30
        fi
        ((attempt++))
    done
    
    print_status "DNS propagation check failed after $max_attempts attempts" "ERROR"
    return 1
}

# Function to configure domain and DNS
configure_domain() {
    display_header "Domain and DNS Configuration"
    
    # Detect and display IP information first
    if ! detect_server_ips; then
        print_status "Failed to detect server IPs. Please check network configuration." "ERROR"
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
    
    # Cloudflare check
    read -p "Are you using Cloudflare? (y/n): " use_cloudflare
    if [[ $use_cloudflare =~ ^[Yy]$ ]]; then
        USE_CLOUDFLARE=true
        print_status "Cloudflare Configuration Instructions:" "INFO"
        echo ""
        print_status "1. Login to your Cloudflare dashboard" "INFO"
        print_status "2. Select your domain" "INFO"
        print_status "3. Go to DNS settings" "INFO"
        print_status "4. Add an A record:" "INFO"
        echo "   - Name: ${DOMAIN%%.*} (subdomain part)"
        echo "   - IPv4 address: $PUBLIC_IP"
        echo "   - Proxy status: DNS only (grey cloud)"
        echo ""
        print_status "5. Go to SSL/TLS settings:" "INFO"
        echo "   - Set encryption mode to 'Full'"
        echo "   - Enable 'Always Use HTTPS'"
        echo ""
        print_status "6. Go to Network settings:" "INFO"
        echo "   - Enable WebSockets if not already enabled"
        echo ""
    else
        USE_CLOUDFLARE=false
        print_status "Standard DNS Configuration Instructions:" "INFO"
        echo ""
        print_status "Add the following DNS record to your domain provider:" "INFO"
        echo "Type: A"
        echo "Name: ${DOMAIN%%.*} (subdomain part)"
        echo "Value: $PUBLIC_IP"
        echo "TTL: 300 (or lowest available)"
        echo ""
    fi
    
    # Wait for user to confirm DNS configuration
    while true; do
        read -p "Have you configured the DNS records as instructed? (y/n): " dns_configured
        if [[ $dns_configured =~ ^[Yy]$ ]]; then
            break
        elif [[ $dns_configured =~ ^[Nn]$ ]]; then
            print_status "Please configure DNS records before continuing." "WARNING"
            read -p "Press Enter to view the instructions again, or type 'exit' to quit: " response
            if [[ $response == "exit" ]]; then
                return 1
            fi
            continue
        fi
    done
    
    # Check DNS propagation
    print_status "Checking DNS configuration..." "INFO"
    if ! check_dns_propagation "$DOMAIN" "$PUBLIC_IP"; then
        print_status "DNS propagation not complete. You have two options:" "WARNING"
        echo "1. Wait for DNS to propagate and run the script again"
        echo "2. Continue anyway (not recommended)"
        read -p "Do you want to continue anyway? (y/n): " continue_anyway
        if [[ ! $continue_anyway =~ ^[Yy]$ ]]; then
            return 1
        fi
    fi
    
    # Configure SSL
    read -p "Would you like to enable SSL/TLS encryption? (y/n): " enable_ssl
    if [[ $enable_ssl =~ ^[Yy]$ ]]; then
        USE_SSL=true
        print_status "SSL/TLS encryption will be enabled during installation." "SUCCESS"
    else
        USE_SSL=false
        print_status "SSL/TLS encryption will not be enabled. You can enable it later manually." "WARNING"
    fi
    
    return 0
}

# Function to setup Docker environment
setup_docker() {
    print_status "Setting up Docker environment..." "INFO"
    
    # Check if Docker is already installed
    if command -v docker &> /dev/null; then
        print_status "Docker is already installed." "INFO"
        # Verify Docker service is running
        if ! systemctl is-active --quiet docker; then
            print_status "Docker service is not running. Starting it..." "WARNING"
            systemctl start docker
            systemctl enable docker
        fi
    else
        print_status "Installing Docker..." "INFO"
        
        # Install dependencies
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
    
    # Verify installations
    if docker --version && docker-compose --version; then
        print_status "Docker environment setup completed successfully." "SUCCESS"
        return 0
    else
        print_status "Docker environment setup failed." "ERROR"
        return 1
    fi
}

# Function to generate enhanced NGINX configuration
generate_nginx_config() {
    local domain="$1"
    local use_ssl="$2"
    local config_file="nginx.conf"
    
    print_status "Generating NGINX configuration..." "INFO"
    
    # Create basic configuration
    cat > "$config_file" << EOF
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
    keepalive_timeout 65;
    server_tokens off;
    client_max_body_size 50M;
    
    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    add_header Content-Security-Policy "default-src 'self' http: https: data: blob: 'unsafe-inline'" always;
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    
    # Optimize SSL
    ssl_session_timeout 1d;
    ssl_session_cache shared:SSL:50m;
    ssl_session_tickets off;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;
    
    # ZeroTier network configuration
    server {
EOF
    
    # Add SSL configuration if enabled
    if [ "$use_ssl" = true ]; then
        cat >> "$config_file" << EOF
        listen 443 ssl http2;
        listen [::]:443 ssl http2;
        server_name ${domain};
        
        ssl_certificate /etc/nginx/certs/fullchain.pem;
        ssl_certificate_key /etc/nginx/certs/privkey.pem;
        
        # OCSP Stapling
        ssl_stapling on;
        ssl_stapling_verify on;
        resolver 1.1.1.1 1.0.0.1 valid=300s;
        resolver_timeout 5s;
EOF
    else
        cat >> "$config_file" << EOF
        listen 80;
        listen [::]:80;
        server_name ${domain};
EOF
    fi
    
    # Add reverse proxy configuration with ZeroTier access control
    cat >> "$config_file" << EOF
        
        # Wazuh API reverse proxy
        location / {
            # Allow ZeroTier network ranges
            allow 10.0.0.0/8;      # ZeroTier managed routes
            allow 172.16.0.0/12;   # ZeroTier managed routes
            allow 192.168.0.0/16;  # ZeroTier managed routes
            deny all;              # Deny all other traffic
            
            proxy_pass https://wazuh.manager:55000;
            proxy_buffer_size 128k;
            proxy_buffers 4 256k;
            proxy_busy_buffers_size 256k;
            proxy_ssl_verify off;
            proxy_http_version 1.1;
            proxy_set_header Upgrade \$http_upgrade;
            proxy_set_header Connection 'upgrade';
            proxy_set_header Host \$host;
            proxy_cache_bypass \$http_upgrade;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;
            
            # WebSocket support
            proxy_read_timeout 90s;
            proxy_set_header Upgrade \$http_upgrade;
            proxy_set_header Connection "upgrade";
        }
        
        # Health check endpoint
        location /health {
            access_log off;
            return 200 'healthy\n';
        }
    }
EOF
    
    # Add HTTP to HTTPS redirect if SSL is enabled
    if [ "$use_ssl" = true ]; then
        cat >> "$config_file" << EOF
    
    # Redirect HTTP to HTTPS
    server {
        listen 80;
        listen [::]:80;
        server_name ${domain};
        return 301 https://\$server_name\$request_uri;
    }
EOF
    fi
    
    cat >> "$config_file" << EOF
}
EOF
    
    print_status "NGINX configuration generated successfully." "SUCCESS"
    return 0
}

# Function to generate Docker Compose configuration
generate_docker_compose() {
    local compose_file="docker-compose.yml"
    print_status "Generating Docker Compose configuration..." "INFO"
    
    cat > "$compose_file" << EOF
version: '3.8'

services:
  wazuh.manager:
    image: wazuh/wazuh-manager:latest
    hostname: wazuh.manager
    restart: always
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

  nginx:
    image: nginx:latest
    hostname: nginx
    restart: always
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

  zerotier:
    image: zerotier/zerotier
    hostname: zerotier
    restart: always
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
  zerotier_data:
EOF
    
    print_status "Docker Compose configuration generated successfully." "SUCCESS"
}

# Function to setup Docker-based Wazuh installation
setup_docker_wazuh() {
    print_status "Setting up Docker-based Wazuh installation..." "INFO"
    
    # Create project directory
    local install_dir="/opt/wazuh-docker"
    mkdir -p "$install_dir"
    cd "$install_dir"
    
    # Generate Docker Compose configuration
    generate_docker_compose
    
    # Generate NGINX configuration
    generate_nginx_config "$DOMAIN" "$USE_SSL"
    
    # Setup SSL if enabled
    if [ "$USE_SSL" = true ]; then
        setup_ssl "$DOMAIN" "$EMAIL"
    fi
    
    # Generate .env file with secure passwords
    generate_env_file
    
    # Start the containers
    print_status "Starting Wazuh containers..." "INFO"
    if docker-compose up -d; then
        print_status "Wazuh containers started successfully." "SUCCESS"
    else
        print_status "Failed to start Wazuh containers." "ERROR"
        return 1
    fi
    
    # Wait for services to be ready
    print_status "Waiting for services to be ready..." "INFO"
    sleep 30
    
    # Verify services
    verify_docker_services
}

# Function to generate secure environment file
generate_env_file() {
    print_status "Generating secure environment configuration..." "INFO"
    
    # Generate random passwords
    local elastic_pass=$(openssl rand -base64 32)
    local indexer_pass=$(openssl rand -base64 32)
    local wazuh_api_pass=$(openssl rand -base64 32)
    
    # Create .env file
    cat > .env << EOF
ELASTIC_PASSWORD=${elastic_pass}
INDEXER_PASSWORD=${indexer_pass}
WAZUH_API_PASSWORD=${wazuh_api_pass}
ZEROTIER_NETWORK_ID=${ZEROTIER_NETWORK_ID}
EOF
    
    chmod 600 .env
    print_status "Secure environment configuration generated." "SUCCESS"
}

# Main execution flow
main() {
    # Clear screen and show welcome message
    clear
    print_status "Welcome to the Enhanced Wazuh Installation Wizard" "INFO"
    print_status "Script started at: $START_TIME" "INFO"
    echo ""
    
    # Check if running as root
    if [ "$EUID" -ne 0 ]; then
        print_status "This script must be run as root. Please use sudo." "ERROR"
        exit 1
    fi
    
    # Check internet connectivity
    if ! check_internet_connectivity; then
        exit 1
    fi
    
    # Display installation options
    print_status "Please select installation type:" "INFO"
    echo "1. Docker-based installation (Recommended)"
    echo "2. Traditional installation"
    echo "3. Uninstall existing installation"
    
    read -p "Enter your choice (1-3): " install_choice
    
    case $install_choice in
        1)
            INSTALL_TYPE="docker"
            ;;
        2)
            INSTALL_TYPE="traditional"
            print_status "Traditional installation is deprecated. Please consider using Docker-based installation." "WARNING"
            read -p "Do you want to continue with traditional installation? (y/n): " continue_traditional
            if [[ ! $continue_traditional =~ ^[Yy]$ ]]; then
                exit 0
            fi
            ;;
        3)
            INSTALL_TYPE="uninstall"
            ;;
        *)
            print_status "Invalid choice. Exiting." "ERROR"
            exit 1
            ;;
    esac
    
    # Configure domain and network
    if [ "$INSTALL_TYPE" != "uninstall" ]; then
        if ! configure_domain; then
            print_status "Domain configuration failed. Exiting." "ERROR"
            exit 1
        fi
        
        if ! verify_network_setup; then
            print_status "Network verification failed. Exiting." "ERROR"
            exit 1
        fi
    fi
    
    # Proceed with selected installation type
    case $INSTALL_TYPE in
        "docker")
            if ! setup_docker; then
                print_status "Docker setup failed. Exiting." "ERROR"
                exit 1
            fi
            if ! setup_docker_wazuh; then
                print_status "Wazuh Docker setup failed. Exiting." "ERROR"
                exit 1
            fi
            ;;
        "traditional")
            traditional_install
            ;;
        "uninstall")
            uninstall_wazuh
            ;;
    esac
    
    print_status "Script completed successfully!" "SUCCESS"
    exit 0
}

# Start script execution
main
