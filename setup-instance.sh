#!/bin/bash

# Script for setting up Prometheus and Grafana on an EC2 instance
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

# Set ENV variables
TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600") || exit_on_error "Failed to retrieve token"
INSTANCE_ID=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/instance-id) || exit_on_error "Failed to retrieve instance ID"
REGION=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/placement/availability-zone | sed 's/[a-z]$//') || exit_on_error "Failed to retrieve region"
export TOKEN INSTANCE_ID REGION

# Retrieve keys from Secrets Manager
CLOUDWATCH_KEYS_JSON=$(aws secretsmanager get-secret-value --secret-id prod/grafana/user --query SecretString --output text) || exit_on_error "Failed to retrieve CloudWatch keys"
ACCESS_KEY=$(echo $CLOUDWATCH_KEYS_JSON | jq -r '.ACCESS_KEY') || exit_on_error "Failed to parse ACCESS_KEY"
SECRET_KEY=$(echo $CLOUDWATCH_KEYS_JSON | jq -r '.SECRET_KEY') || exit_on_error "Failed to parse SECRET_KEY"
export ACCESS_KEY SECRET_KEY

# Update system packages
log "Updating system packages..."
sudo yum update -y || exit_on_error "Failed to update packages"

# Install AWS CLI and jq (if not already installed)
log "Installing AWS CLI and jq..."
sudo yum install -y aws-cli jq || exit_on_error "Failed to install AWS CLI and jq"

# Retrieve Grafana admin password from Secrets Manager
GRAFANA_PASSWORD=$(aws secretsmanager get-secret-value --secret-id prod/grafana/password --query SecretString --output text) || exit_on_error "Failed to retrieve Grafana password"
GRAF_PASSWORD=$(echo $GRAFANA_PASSWORD | jq -r '.GRAFANA_PASSWORD') || exit_on_error "Failed to parse GRAFANA_PASSWORD"
export GRAF_PASSWORD

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

# Create configuration files and Docker Compose setup
log "Creating configuration files and setting up Docker Compose..."
(cd /home/ec2-user && sudo -u ec2-user bash -c '
cat <<EOL > prometheus.yml
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: "prometheus"
    static_configs:
      - targets: ["localhost:9090"]
EOL

cat <<EOL > datasource.yaml
apiVersion: 1

datasources:
  - name: CloudWatch
    type: cloudwatch
    jsonData:
      authType: keys
      defaultRegion: $REGION
    secureJsonData:
      accessKey: "$ACCESS_KEY"
      secretKey: "$SECRET_KEY"
  - name: Prometheus
    type: prometheus
    url: http://localhost:9090
    access: proxy
    isDefault: true
EOL

cat <<EOL > docker-compose.yml
version: "3"
services:
  prometheus:
    image: prom/prometheus:latest
    restart: always
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml

  grafana:
    image: grafana/grafana:latest
    restart: always
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=$GRAF_PASSWORD
      - GF_SECURITY_DISABLE_INITIAL_ADMIN_PASSWORD_HINT=true
    ports:
      - "3000:3000"
    volumes:
      - grafana-storage:/var/lib/grafana
      - ./datasource.yaml:/etc/grafana/provisioning/datasources/datasource.yaml

volumes:
  grafana-storage:
EOL
') || exit_on_error "Failed to create configuration files"

# Start Docker Compose
log "Starting Docker Compose..."
cd /home/ec2-user
sudo docker-compose up -d || exit_on_error "Failed to start Docker Compose"

log "Setup completed successfully."
