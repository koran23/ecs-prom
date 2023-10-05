resource "aws_security_group" "promgraf" {
  name        = "ec2_security_group"
  description = "Allow inbound SSH and other necessary traffic"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # This is wide open for demonstration purposes only!!!
  }

  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  vpc_id = aws_default_vpc.default_vpc.id
}

resource "aws_instance" "promgraf_linux" {
  ami           = var.ami_id
  instance_type = var.instance_type

  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.promgraf.id]

# REPLACE PROMETHEUS TARGET WITH THE NAME OF YOUR LOAD BALANCER!!!
  user_data = <<-EOF
              #!/bin/bash
              
              # Redirect stdout and stderr to a log file
              exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

              echo "Updating system packages..."
              sudo yum update -y

              echo "Installing Docker..."
              sudo amazon-linux-extras install docker
              sudo yum install docker -y
              sudo service docker start
              sudo usermod -a -G docker ec2-user

              echo "Installing Docker Compose..."
              sudo curl -L https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m) -o /usr/local/bin/docker-compose
              sudo chmod +x /usr/local/bin/docker-compose

              echo "Creating prometheus.yml..."
              cat <<EOL > /home/ec2-user/prometheus.yml
              global:
                scrape_interval: 15s

              scrape_configs:
                - job_name: 'prometheus'
                  static_configs:
                    - targets: ['<YOUR-LOAD-BALANCER-HERE>'] 
              EOL

              echo "Creating docker-compose.yml..."
              cat <<EOL > /home/ec2-user/docker-compose.yml
              version: '3'
              services:
                prometheus:
                  image: prom/prometheus:latest
                  container_name: prometheus
                  ports:
                    - "9090:9090"
                  volumes:
                    - ./prometheus.yml:/etc/prometheus/prometheus.yml
                  command:
                    - '--config.file=/etc/prometheus/prometheus.yml'

                grafana:
                  image: grafana/grafana:latest
                  container_name: grafana
                  ports:
                    - "3000:3000"
                  volumes:
                    - grafana-storage:/var/lib/grafana
                  environment:
                    - GF_SECURITY_ADMIN_PASSWORD=mysecretpassword

              volumes:
                grafana-storage:
              EOL
              cd /home/ec2-user
              sudo docker-compose up -d
              EOF

  tags = {
    Name = "PromGrafLinuxInstance"
  }
}
