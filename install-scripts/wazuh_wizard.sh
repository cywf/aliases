#!/bin/bash

# Enhanced Wazuh setup script with Docker support, domain management, and improved error handling
# Includes options for traditional or container-based installation

# Enable strict error handling
set -e

# Variables
LOG_FILE="wazuh_setup.log"
START_TIME=$(date)
step_counter=1
MAX_RETRIES=3
TIMEOUT_BETWEEN_RETRIES=5
DOCKER_COMPOSE_VERSION="2.21.0"  # Specify the desired version

# Installation type (will be set by user choice)
INSTALL_TYPE=""

# Domain-related variables
DOMAIN=""
EMAIL=""
USE_SSL=false

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

# Function to handle errors
error_exit() {
    print_status "Error on line $1: $2" "ERROR"
    print_status "For more details, check the log file: $LOG_FILE" "INFO"
    exit 1
}

# Enhanced internet connectivity check
check_internet_connectivity() {
    print_status "Checking internet connectivity..." "INFO"
    
    local test_urls=("google.com" "cloudflare.com" "1.1.1.1" "packages.wazuh.com")
    local success=false
    
    for url in "${test_urls[@]}"; do
        if ping -c 1 "$url" &> /dev/null; then
            success=true
            break
        fi
    done
    
    if ! $success; then
        print_status "No internet connectivity detected. Please check your connection and try again." "ERROR"
        print_status "Troubleshooting steps:" "INFO"
        print_status "1. Check your network cable or Wi-Fi connection" "INFO"
        print_status "2. Verify DNS settings in /etc/resolv.conf" "INFO"
        print_status "3. Try 'ping google.com' to test basic connectivity" "INFO"
        print_status "4. Check if a proxy is required for your network" "INFO"
        return 1
    fi
    
    print_status "Internet connectivity confirmed." "SUCCESS"
    return 0
}

# Enhanced APT handling
handle_apt_issues() {
    print_status "Checking APT system status..." "INFO"
    
    # Check for locked database
    if fuser /var/lib/dpkg/lock &>/dev/null; then
        print_status "APT database is locked. Attempting to resolve..." "WARNING"
        sleep 10
        if fuser /var/lib/dpkg/lock &>/dev/null; then
            print_status "Could not acquire APT lock. Please ensure no other package managers are running." "ERROR"
            return 1
        fi
    fi
    
    # Fix potentially corrupt lists
    print_status "Cleaning package lists..." "INFO"
    rm -rf /var/lib/apt/lists/*
    mkdir -p /var/lib/apt/lists/partial
    
    # Update package lists with multiple retries
    local attempt=1
    local max_attempts=3
    
    while [ $attempt -le $max_attempts ]; do
        print_status "Updating package lists (attempt $attempt/$max_attempts)..." "INFO"
        if apt update 2>&1 | tee -a "$LOG_FILE"; then
            print_status "Package lists updated successfully." "SUCCESS"
            return 0
        else
            if [ $attempt -lt $max_attempts ]; then
                print_status "Update failed. Waiting before retry..." "WARNING"
                sleep $((attempt * 5))
            fi
        fi
        ((attempt++))
    done
    
    print_status "Failed to update package lists after $max_attempts attempts." "ERROR"
    print_status "Troubleshooting steps:" "INFO"
    print_status "1. Check /etc/apt/sources.list for invalid repositories" "INFO"
    print_status "2. Verify network connectivity to package repositories" "INFO"
    print_status "3. Try 'apt clean' and then retry the installation" "INFO"
    return 1
}

# Function to validate domain
validate_domain() {
    local domain="$1"
    if [[ ! "$domain" =~ ^[a-zA-Z0-9][a-zA-Z0-9-]{1,61}[a-zA-Z0-9]\.[a-zA-Z]{2,}$ ]]; then
        return 1
    fi
    return 0
}

# Function to check and install Docker
setup_docker() {
    print_status "Setting up Docker environment..." "INFO"
    
    # Check if Docker is already installed
    if command -v docker &> /dev/null; then
        print_status "Docker is already installed." "INFO"
    else
        print_status "Installing Docker..." "INFO"
        
        # Install dependencies
        apt-get install -y \
            apt-transport-https \
            ca-certificates \
            curl \
            gnupg \
            lsb-release
        
        # Add Docker's official GPG key
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
        
        # Set up the stable repository
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
    
    # Install Docker Compose if not present
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

# Function to configure domain and DNS
configure_domain() {
    print_status "Beginning domain configuration..." "INFO"
    
    # Prompt for domain
    while true; do
        read -p "Enter your domain name (e.g., wazuh.yourdomain.com): " DOMAIN
        if validate_domain "$DOMAIN"; then
            break
        else
            print_status "Invalid domain format. Please enter a valid domain name." "ERROR"
        fi
    done
    
    # Prompt for email (for SSL certificates)
    while true; do
        read -p "Enter your email address (for SSL certificates): " EMAIL
        if [[ "$EMAIL" =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]]; then
            break
        else
            print_status "Invalid email format. Please enter a valid email address." "ERROR"
        fi
    done
    
    # Display DNS configuration instructions
    print_status "Domain Configuration Instructions:" "INFO"
    echo ""
    print_status "Please configure the following DNS records for your domain:" "INFO"
    print_status "1. Create an A record for: $DOMAIN" "INFO"
    print_status "2. Point it to your server's IP address" "INFO"
    echo ""
    print_status "If you're using Cloudflare, please ensure that:" "INFO"
    print_status "- SSL/TLS encryption mode is set to 'Full'" "INFO"
    print_status "- Always Use HTTPS is enabled" "INFO"
    echo ""
    
    # Verify DNS propagation
    read -p "Have you configured the DNS records? (y/n): " dns_configured
    if [[ $dns_configured =~ ^[Yy]$ ]]; then
        print_status "Checking DNS propagation..." "INFO"
        
        local max_attempts=5
        local attempt=1
        local propagated=false
        
        while [ $attempt -le $max_attempts ]; do
            if host "$DOMAIN" &>/dev/null; then
                propagated=true
                break
            else
                print_status "DNS not propagated yet. Attempt $attempt/$max_attempts" "WARNING"
                sleep 30
            fi
            ((attempt++))
        done
        
        if [ "$propagated" = true ]; then
            print_status "DNS propagation confirmed." "SUCCESS"
            USE_SSL=true
        else
            print_status "DNS propagation not detected. Continuing without SSL..." "WARNING"
            print_status "You can configure SSL manually later." "INFO"
            USE_SSL=false
        fi
    else
        print_status "Continuing without DNS configuration. SSL will not be enabled." "WARNING"
        USE_SSL=false
    fi
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
      - ELASTIC_PASSWORD=changeme
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
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf:ro
      - ./certs:/etc/nginx/certs
    depends_on:
      - wazuh.manager
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
EOF

    print_status "Docker Compose configuration generated." "SUCCESS"
}

# Function to generate NGINX configuration
generate_nginx_config() {
    local domain="$1"
    local use_ssl="$2"
    local config_file="nginx.conf"
    
    print_status "Generating NGINX configuration..." "INFO"
    
    # Basic configuration
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
    
    # Security headers
    add_header X-Frame-Options "SAMEORIGIN";
    add_header X-XSS-Protection "1; mode=block";
    add_header X-Content-Type-Options "nosniff";
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    
    # Wazuh API reverse proxy
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
        ssl_session_timeout 1d;
        ssl_session_cache shared:SSL:50m;
        ssl_session_tickets off;
        
        # Modern configuration
        ssl_protocols TLSv1.2 TLSv1.3;
        ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384;
        ssl_prefer_server_ciphers off;
        
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
    
    # Common configuration
    cat >> "$config_file" << EOF
        
        # Proxy settings
        location / {
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
        }
        
        # Health check
        location /health {
            access_log off;
            return 200 'healthy\n';
        }
    }
EOF
    
    # HTTP redirect to HTTPS if SSL is enabled
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
}

# Function to setup SSL with Let's Encrypt
setup_ssl() {
    local domain="$1"
    local email="$2"
    
    print_status "Setting up SSL with Let's Encrypt..." "INFO"
    
    # Create directory for certificates
    mkdir -p certs
    
    # Add Certbot container to docker-compose.yml
    cat >> docker-compose.yml << EOF

  certbot:
    image: certbot/certbot
    volumes:
      - ./certs:/etc/letsencrypt
      - ./certbot/www:/var/www/certbot
    command: certonly --webroot --webroot-path=/var/www/certbot --email ${email} --agree-tos --no-eff-email -d ${domain}
EOF
    
    # Initial certificate request
    print_status "Requesting SSL certificate..." "INFO"
    if docker-compose run --rm certbot; then
        print_status "SSL certificate obtained successfully." "SUCCESS"
        
        # Copy certificates to nginx certs directory
        cp certs/live/$domain/fullchain.pem certs/
        cp certs/live/$domain/privkey.pem certs/
        
        # Set proper permissions
        chmod 644 certs/fullchain.pem
        chmod 644 certs/privkey.pem
        
        # Setup auto-renewal
        setup_ssl_renewal
    else
        print_status "Failed to obtain SSL certificate." "ERROR"
        USE_SSL=false
        return 1
    fi
}

# Function to setup SSL auto-renewal
setup_ssl_renewal() {
    print_status "Setting up SSL auto-renewal..." "INFO"
    
    # Create renewal script
    cat > ssl-renewal.sh << 'EOF'
#!/bin/bash
docker-compose run --rm certbot renew
docker-compose exec nginx nginx -s reload
EOF
    
    chmod +x ssl-renewal.sh
    
    # Add to crontab
    (crontab -l 2>/dev/null; echo "0 12 * * * $(pwd)/ssl-renewal.sh") | crontab -
    
    print_status "SSL auto-renewal configured." "SUCCESS"
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

# Function to verify Docker services
verify_docker_services() {
    print_status "Verifying Docker services..." "INFO"
    
    local services=("wazuh.manager" "nginx")
    local all_running=true
    
    for service in "${services[@]}"; do
        if ! docker-compose ps "$service" | grep -q "Up"; then
            print_status "Service $service is not running properly." "ERROR"
            all_running=false
        fi
    done
    
    if [ "$all_running" = true ]; then
        print_status "All Docker services are running properly." "SUCCESS"
        return 0
    else
        print_status "Some services failed to start. Check the logs with 'docker-compose logs'" "ERROR"
        return 1
    fi
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
            ;;
        3)
            INSTALL_TYPE="uninstall"
            ;;
        *)
            print_status "Invalid choice. Exiting." "ERROR"
            exit 1
            ;;
    esac
    
    # Handle domain configuration
    if [ "$INSTALL_TYPE" != "uninstall" ]; then
        configure_domain
    fi
    
    # Proceed with selected installation type
    case $INSTALL_TYPE in
        "docker")
            print_status "Proceeding with Docker-based installation..." "INFO"
            
            # Setup Docker environment
            if ! setup_docker; then
                print_status "Docker setup failed. Exiting." "ERROR"
                exit 1
            fi
            
            # Setup Wazuh with Docker
            if ! setup_docker_wazuh; then
                print_status "Wazuh Docker setup failed. Exiting." "ERROR"
                exit 1
            fi
            ;;
            
        "traditional")
            print_status "Traditional installation selected." "INFO"
            print_status "This installation type is not recommended. Please consider using Docker-based installation." "WARNING"
            read -p "Do you want to continue anyway? (y/n): " continue_traditional
            if [[ $continue_traditional =~ ^[Yy]$ ]]; then
                # Call traditional installation function (from previous script)
                traditional_install
            else
                print_status "Installation cancelled." "INFO"
                exit 0
            fi
            ;;
            
        "uninstall")
            print_status "Proceeding with uninstallation..." "INFO"
            if [ -f "docker-compose.yml" ]; then
                print_status "Docker installation detected. Removing containers and volumes..." "INFO"
                docker-compose down -v
                rm -rf /opt/wazuh-docker
            fi
            uninstall_wazuh
            ;;
    esac
    
    # Display completion message and information
    if [ "$INSTALL_TYPE" != "uninstall" ]; then
        print_status "Installation completed successfully!" "SUCCESS"
        echo ""
        print_status "Access Information:" "INFO"
        if [ "$USE_SSL" = true ]; then
            print_status "Wazuh Dashboard: https://$DOMAIN" "INFO"
        else
            print_status "Wazuh Dashboard: http://$DOMAIN" "INFO"
        fi
        print_status "Default credentials: admin / admin" "INFO"
        print_status "Please change the default password after first login." "WARNING"
        echo ""
        print_status "Installation directory: /opt/wazuh-docker" "INFO"
        print_status "Configuration files:" "INFO"
        print_status "- Docker Compose: docker-compose.yml" "INFO"
        print_status "- NGINX: nginx.conf" "INFO"
        if [ "$USE_SSL" = true ]; then
            print_status "- SSL certificates: ./certs/" "INFO"
        fi
    else
        print_status "Uninstallation completed successfully!" "SUCCESS"
    fi
    
    print_status "Script completed at: $(date)" "INFO"
}

# Trap errors
trap 'error_exit ${LINENO} "$BASH_COMMAND"' ERR

# Start script execution
main
