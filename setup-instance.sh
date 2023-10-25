#!/bin/bash

# Redirect stdout and stderr to a log file
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

# Update system packages
yum update -y

# Install Docker
amazon-linux-extras install docker -y
service docker start
usermod -a -G docker ec2-user

# Install Docker Compose
curl -L https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m) -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Prometheus configuration
cat <<EOL > /home/ec2-user/prometheus.yml
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['<YOUR-LOAD-BALANCER-HERE>'] 
EOL

# Docker Compose configuration
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
      - GF_SECURITY_ADMIN_PASSWORD=mysecretpassword
    volumes:
      - grafana-storage:/var/lib/grafana

volumes:
  grafana-storage:
EOL
