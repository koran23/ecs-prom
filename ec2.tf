resource "aws_security_group" "monitoring" {
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

resource "aws_instance" "monitoring_instance" {
  ami           = var.ami_id
  instance_type = var.instance_type

  key_name               = var.key_name
  iam_instance_profile = aws_iam_instance_profile.ec2_profile.name
  vpc_security_group_ids = [aws_security_group.monitoring.id]

  associate_public_ip_address = true

  user_data = file("setup-instance.sh")

  tags = {
    Name = "MonitoringInstance"
  }
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "EC2MonitoringProfile"
  role = aws_iam_role.ec2_role.name
}

resource "aws_eip" "monitoring_eip" {
  instance = aws_instance.monitoring_instance.id
}
