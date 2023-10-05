output "load_balancer_dns_name" {
  description = "The DNS name of the application load balancer."
  value       = aws_alb.alb.dns_name
}

output "promgraf_linux_public_ip" {
  description = "The public IP of the promgraf Linux EC2 instance."
  value       = aws_instance.promgraf_linux.public_ip
}