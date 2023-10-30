output "monitoring_instance_public_ip" {
  description = "The public IP of the promgraf Linux EC2 instance."
  value       = aws_instance.monitoring_instance.public_ip
}

output "monitoring_instance_eip" {
  value = aws_eip.monitoring_eip.public_ip
  description = "The Elastic IP address of the monitoring instance"
}