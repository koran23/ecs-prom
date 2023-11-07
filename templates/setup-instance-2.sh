#!/bin/bash

# Script for setting up Prometheus, Grafana, and Thanos on an EC2 instance
# Usage: ./setup_monitoring.sh

# Redirect stdout and stderr to a log file
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

exit_on_error() {
  log "Error: $1. Exiting."
  exit 1
}

# Retrieve keys from Secrets Manager
ACCESS_KEY="${grafana_keys["ACCESS_KEY"]}"
SECRET_KEY="${grafana_keys["SECRET_KEY"]}"
GRAFANA_PASSWORD="${grafana_password["GRAFANA_PASSWORD"]}"

# Set ENV variables
TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600") || exit_on_error "Failed to retrieve token"
INSTANCE_ID=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/instance-id) || exit_on_error "Failed to retrieve instance ID"
REGION=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/placement/availability-zone | sed 's/[a-z]$//') || exit_on_error "Failed to retrieve region"
BUCKET="${thanos_bucket_name}"

# Update system packages
log "Updating system packages..."
sudo yum update -y || exit_on_error "Failed to update packages"

# Install AWS CLI and jq (if not already installed)
log "Installing AWS CLI and jq..."
sudo yum install -y aws-cli jq || exit_on_error "Failed to install AWS CLI and jq"

# Install Docker
log "Installing Docker..."
sudo yum install -y docker || exit_on_error "Failed to install Docker"
sudo service docker start || exit_on_error "Failed to start Docker"
sudo usermod -a -G docker ec2-user || exit_on_error "Failed to add ec2-user to Docker group"

# Install Docker Compose
DOCKER_COMPOSE_VERSION="1.29.2"
log "Installing Docker Compose version $DOCKER_COMPOSE_VERSION..."
sudo curl -L "https://github.com/docker/compose/releases/download/$DOCKER_COMPOSE_VERSION/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose || exit_on_error "Failed to download Docker Compose"
sudo chmod +x /usr/local/bin/docker-compose || exit_on_error "Failed to make Docker Compose executable"

# Install libcrypt
sudo yum install libxcrypt-compat -y || exit_on_error "Faild to install Docker"

# Create configuration files and Docker Compose setup
log "Creating configuration files and setting up Docker Compose..."

# Change to ec2-user's home directory to create files with the correct owner
cd /home/ec2-user

# Prometheus configuration file
cat > prometheus.yml <<EOL
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: "prometheus"
    static_configs:
      - targets: ["localhost:9090"]
  - job_name: "thanos-sidecar"
    static_configs:
      - targets: ["localhost:19191"]
EOL

# Grafana datasource configuration file
cat > datasource.yaml <<EOL
apiVersion: 1

datasources:
  - name: CloudWatch
    type: cloudwatch
    jsonData:
      authType: keys
      defaultRegion: $${REGION}
    secureJsonData:
      accessKey: $${ACCESS_KEY}
      secretKey: $${SECRET_KEY}
  - name: Prometheus
    type: prometheus
    url: http://localhost:9090
    access: proxy
    isDefault: true
EOL

# Thanos storage configuration file
cat > thanos-storage-config.yaml <<EOL
type: S3
config:
  bucket: $${BUCKET}
  endpoint: "s3.amazonaws.com"
  access_key: $${ACCESS_KEY}
  secret_key: $${SECRET_KEY}
  insecure: false
  signature_version2: false
EOL

# Docker Compose file
cat > docker-compose.yml <<EOL
version: "3"
services:
  prometheus:
    image: prom/prometheus:latest
    restart: always
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml
    command:
      - "--config.file=/etc/prometheus/prometheus.yml"
      - "--storage.tsdb.path=/prometheus"
      - "--web.console.libraries=/usr/share/prometheus/console_libraries"
      - "--web.console.templates=/usr/share/prometheus/consoles"
  thanos-sidecar:
    image: quay.io/thanos/thanos:v0.25.0
    restart: always
    command:
      - "sidecar"
      - "--tsdb.path=/prometheus"
      - "--objstore.config-file=/etc/thanos/thanos-storage-config.yaml"
      - "--grpc-address=0.0.0.0:10901"
      - "--http-address=0.0.0.0:19191"
    volumes:
      - ./thanos-storage-config.yaml:/etc/thanos/thanos-storage-config.yaml
      - prometheus_data:/prometheus
    ports:
      - "19191:19191"
      - "10901:10901"
  grafana:
    image: grafana/grafana:latest
    restart: always
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=$${GRAFANA_PASSWORD}
      - GF_SECURITY_DISABLE_INITIAL_ADMIN_PASSWORD_HINT=true
    ports:
      - "3000:3000"
    volumes:
      - grafana-storage:/var/lib/grafana
      - ./datasource.yaml:/etc/grafana/provisioning/datasources/datasource.yaml

volumes:
  prometheus_data:
  grafana_storage:
EOL

# Change ownership of the created files to ec2-user
sudo chown ec2-user:ec2-user prometheus.yml datasource.yaml thanos-storage-config.yaml docker-compose.yml

# Start Docker Compose
log "Starting Docker Compose..."
sudo docker-compose up -d || exit_on_error "Failed to start Docker Compose"

log "Setup completed successfully with Thanos integration."
