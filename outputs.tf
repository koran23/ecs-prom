output "load_balancer_dns_name" {
  description = "The DNS name of the application load balancer."
  value       = aws_alb.alb.dns_name
}

output "promgraf_linux_public_ip" {
  description = "The public IP of the promgraf Linux EC2 instance."
  value       = aws_instance.monitoring_instance.public_ip
}

output "monitoring_instance_eip" {
  value = aws_eip.monitoring_eip.public_ip
  description = "The Elastic IP address of the monitoring instance"
}
