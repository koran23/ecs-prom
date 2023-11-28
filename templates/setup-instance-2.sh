#!/bin/bash

# Script for setting up Prometheus, Grafana on an EC2 instance
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

# Update system packages
log "Updating system packages..."
sudo yum update -y || exit_on_error "Failed to update packages"

# Install AWS CLI and jq (if not already installed)
log "Installing Python AWS CLI and jq..."
sudo yum install -y python3 aws-cli jq || exit_on_error "Failed to install Python AWS CLI and jq"

# Install Docker
log "Installing Docker..."
sudo yum install -y docker || exit_on_error "Failed to install Docker"
sudo service docker start || exit_on_error "Failed to start Docker"
sudo usermod -a -G docker ec2-user || exit_on_error "Failed to add ec2-user to Docker group"

# Authenticate Docker with ECR
log "Authenticating Docker with AWS ECR..."
aws ecr get-login-password --region $REGION | sudo docker login --username AWS --password-stdin 369383612283.dkr.ecr.us-east-1.amazonaws.com || exit_on_error "Failed to authenticate Docker with AWS ECR"

# Install Docker Compose
DOCKER_COMPOSE_VERSION="1.29.2"
log "Installing Docker Compose version $DOCKER_COMPOSE_VERSION..."
sudo curl -L "https://github.com/docker/compose/releases/download/$DOCKER_COMPOSE_VERSION/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose || exit_on_error "Failed to download Docker Compose"
sudo chmod +x /usr/local/bin/docker-compose || exit_on_error "Failed to make Docker Compose executable"

# Install libcrypt
sudo yum install libxcrypt-compat -y || exit_on_error "Failed to install Docker"

# Grafana EBS Volume Setup
EBS_DEVICE="/dev/xvdh" # Update with your EBS volume device name
GRAFANA_STORAGE_PATH="/mnt/grafana-storage"

log "Formatting and mounting the EBS Volume for Grafana..."
sudo mkfs -t xfs $EBS_DEVICE || exit_on_error "Failed to format EBS volume"
sudo mkdir -p $GRAFANA_STORAGE_PATH || exit_on_error "Failed to create mount directory"
sudo mount $EBS_DEVICE $GRAFANA_STORAGE_PATH || exit_on_error "Failed to mount EBS volume"
echo "$EBS_DEVICE $GRAFANA_STORAGE_PATH xfs defaults,nofail 0 2" | sudo tee -a /etc/fstab || exit_on_error "Failed to update fstab"

# Change ownership of the Grafana storage path to the Grafana user (UID 472)
sudo chown -R 472:472 $GRAFANA_STORAGE_PATH || exit_on_error "Failed to change ownership of Grafana storage path"

# Create configuration files and Docker Compose setup
log "Creating configuration files and setting up Docker Compose..."

# Change to ec2-user's home directory to create files with the correct owner
cd /home/ec2-user

# Prometheus configuration file
cat > prometheus.yml <<EOL
global:
  scrape_interval: 15s
  external_labels:
    env: "test"
    region: "us-east-1"
    replica: "instance-01"

scrape_configs:
  - job_name: 'ecs-tasks'
    file_sd_configs:
    - files:
        - '/etc/prometheus/targets/targets.json'
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
    url: http://prometheus:9090
    access: proxy
    isDefault: true
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
      - prometheus_targets:/etc/prometheus/targets
    command:
      - "--config.file=/etc/prometheus/prometheus.yml"
      - "--storage.tsdb.path=/prometheus"
      - "--storage.tsdb.min-block-duration=2h"
      - "--storage.tsdb.max-block-duration=2h"
      - "--web.console.libraries=/usr/share/prometheus/console_libraries"
      - "--web.console.templates=/usr/share/prometheus/consoles"
  service-discovery:
    image: 369383612283.dkr.ecr.us-east-1.amazonaws.com/service_discovery:latest
    volumes:
      - prometheus_targets:/etc/prometheus/targets
    entrypoint: /bin/sh
    command: -c "while true; do python ./fetch_tasks.py; sleep 300; done"
  grafana:
    image: grafana/grafana:latest
    restart: always
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=$${GRAFANA_PASSWORD}
      - GF_SECURITY_DISABLE_INITIAL_ADMIN_PASSWORD_HINT=true
    ports:
      - "3000:3000"
    volumes:
      - ./datasource.yaml:/etc/grafana/provisioning/datasources/datasource.yaml
      - $${GRAFANA_STORAGE_PATH}:/var/lib/grafana

volumes:
  prometheus_data:
  grafana_storage:
  prometheus_targets:
EOL

# Change ownership of the created files to ec2-user
sudo chown ec2-user:ec2-user prometheus.yml datasource.yaml docker-compose.yml

# Start Docker Compose
log "Starting Docker Compose..."
sudo docker-compose up -d || exit_on_error "Failed to start Docker Compose"

log "Setup completed successfully."
