data "aws_secretsmanager_secret" "grafana_user" {
  name = "grafana-keys"
}

data "aws_secretsmanager_secret_version" "grafana_user" {
  secret_id = data.aws_secretsmanager_secret.grafana_user.id
}

data "aws_secretsmanager_secret" "grafana_login" {
  name = "grafana-password"
}

data "aws_secretsmanager_secret_version" "grafana_login" {
  secret_id = data.aws_secretsmanager_secret.grafana_login.id
}

data "aws_instance" "existing_instance" {
  instance_id = aws_instance.monitoring_instance.id
}

resource "aws_security_group" "monitoring" {
  name        = "ec2_security_group"
  description = "Allow inbound SSH and other necessary traffic"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Note: This is wide open for demonstration purposes only!
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

resource "aws_instance" "monitoring_instance" {
  ami           = var.ami_id
  instance_type = var.instance_type

  key_name               = var.key_name
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name
  vpc_security_group_ids = [aws_security_group.monitoring.id]

  associate_public_ip_address = true

  user_data = templatefile("${path.module}/templates/setup-instance-2.sh", {
    grafana_keys       = jsondecode(data.aws_secretsmanager_secret_version.grafana_user.secret_string),
    grafana_password   = jsondecode(data.aws_secretsmanager_secret_version.grafana_login.secret_string),
    thanos_bucket_name = aws_s3_bucket.thanos_bucket.bucket
    region             = var.region
  })

  tags = {
    Name = "MonitoringInstance"
  }

  depends_on = [
    aws_ecs_service.app
  ]

}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "EC2MonitoringProfile"
  role = aws_iam_role.ec2_role.name
}

resource "aws_eip" "monitoring_eip" {
  instance = aws_instance.monitoring_instance.id
}

# Define an EBS volume
resource "aws_ebs_volume" "grafana_volume" {
  availability_zone = data.aws_instance.existing_instance.availability_zone
  size              = 10 # Size in GB, adjust as needed
  type              = "gp2" # General purpose SSD, adjust type as needed

  tags = {
    Name = "GrafanaVolume"
  }
}

# Attach the EBS volume to the monitoring instance
resource "aws_volume_attachment" "grafana_volume_attachment" {
  device_name = "/dev/xvdh" # Ensure this matches the device name in your user-data script
  volume_id   = aws_ebs_volume.grafana_volume.id
  instance_id = aws_instance.monitoring_instance.id

  # Force detach the volume on instance termination
  force_detach = true
}
