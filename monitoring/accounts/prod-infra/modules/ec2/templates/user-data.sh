#!/bin/bash

# Redirect stdout and stderr to a log file
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

# Set ENV variables
export TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600") || exit 1
export INSTANCE_ID=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/instance-id) || exit 1
export REGION=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/placement/availability-zone | sed 's/[a-z]$//') || exit 1

# Retrieve keys from Secrets Manager
export CLOUDWATCH_KEYS_JSON=$(aws secretsmanager get-secret-value --secret-id prod/grafana/user --query SecretString --output text) || exit 1
export ACCESS_KEY=$(echo $CLOUDWATCH_KEYS_JSON | jq -r '.ACCESS_KEY') || exit 1
export SECRET_KEY=$(echo $CLOUDWATCH_KEYS_JSON | jq -r '.SECRET_KEY') || exit 1

# Update system packages
sudo yum update -y || exit 1

# Install AWS CLI and jq (if not already installed)
sudo yum install -y aws-cli jq || exit 1

# Retrieve Grafana admin password from Secrets Manager
export GRAFANA_PASSWORD=$(aws secretsmanager get-secret-value --secret-id prod/grafana/password --query SecretString --output text) || exit 1
export GRAF_PASSWORD=$(echo $GRAFANA_PASSWORD | jq -r '.GRAFANA_PASSWORD') || exit 1
echo "export GRAF_PASSWORD=$GRAFANA_PASSWORD" >> /etc/profile.d/env_vars.sh || exit 1

# Install Docker
sudo yum install -y docker || exit 1
sudo service docker start || exit 1
sudo usermod -a -G docker ec2-user || exit 1

# Install Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose || exit 1
sudo chmod +x /usr/local/bin/docker-compose || exit 1

# Prometheus configuration
cat <<EOL > /home/ec2-user/prometheus.yml
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['<LOAD-BALANCER>']
EOL

# Grafana CloudWatch data source provisioning
cat <<EOL > /home/ec2-user/datasource.yaml
apiVersion: 1

datasources:
  - name: CloudWatch
    type: cloudwatch
    jsonData:
      authType: keys
      defaultRegion: $REGION
    secureJsonData:
      accessKey: '$ACCESS_KEY'
      secretKey: '$SECRET_KEY'
  - name: Prometheus
    type: prometheus
    url: http://localhost:9090
    access: proxy
    isDefault: true
EOL

# Docker Compose Configuration
cat <<EOL > /home/ec2-user/docker-compose.yml
version: '3'
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
    ports:
      - "3000:3000"
    volumes:
      - grafana-storage:/var/lib/grafana
      - ./datasource.yaml:/etc/grafana/provisioning/datasources/datasource.yaml

volumes:
  grafana-storage:
EOL

cd /home/ec2-user

while ! sudo docker info; do
  echo "Waiting for Docker to start..."
  sleep 1
done

sudo docker-compose up -d
