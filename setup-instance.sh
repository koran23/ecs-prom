#!/bin/bash

# Redirect stdout and stderr to a log file
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

# Set ENV variables
TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
INSTANCE_ID=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/instance-id)
REGION=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/placement/availability-zone | sed 's/[a-z]$//')

# Update system packages
sudo yum update -y

# Install AWS CLI (if not already installed)
sudo yum install aws-cli -y

# Retrieve secret from Secrets Manager
# GRAFANA_PASSWORD=$(aws secretsmanager get-secret-value --secret-id YOUR_SECRET_ID_HERE --query SecretString --output text)

# Install Docker
sudo amazon-linux-extras install docker
sudo yum install docker -y
sudo service docker start
sudo usermod -a -G docker ec2-user

# Install Docker Compose
sudo curl -L https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m) -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Prometheus configuration
cat <<EOL > /home/ec2-user/prometheus.yml
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['<LOAD-BALANCER>']

  - job_name: 'cloudwatch-exporter'
    static_configs:
      - targets: ['cloudwatch-exporter:9106']
EOL

# CloudWatch Exporter Configuration
cat <<EOL > /home/ec2-user/cloudwatch-exporter-config.yml
---
region: $REGION  
metrics:
 - aws_namespace: AWS/EC2
   aws_metric_name: CPUUtilization
   aws_dimensions: [InstanceId]
   aws_dimension_select:
     InstanceId: [$INSTANCE_ID]  
   aws_statistics: [Average]
EOL

# Docker Compose Configuration (Including CloudWatch Exporter)
cat <<EOL > /home/ec2-user/docker-compose.yml
version: '3'
services:
  prometheus:
    image: prom/prometheus:latest
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml

  grafana:
    image: grafana/grafana:latest
    ports:
      - "3000:3000"
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin
    volumes:
      - grafana-storage:/var/lib/grafana

  cloudwatch-exporter:
    image: prom/cloudwatch-exporter:latest
    ports:
      - "9106:9106"
    volumes:
      - ./cloudwatch-exporter-config.yml:/config.yml

volumes:
  grafana-storage:
EOL
