variable "region" {
  description = "The AWS region where resources will be created."
  default     = "us-east-1"
}

variable "ami_id" {
  description = "The AMI ID to use for the EC2 instance."
  default     = "ami-067d1e60475437da2"
}

variable "instance_type" {
  description = "The type of EC2 instance to launch."
  default     = "t2.micro"
}

variable "key_name" {
  description = "The name of the key pair for the EC2 instance."
  default     = "prom-keypair"
}

variable "app_name" {
  description = "The name of the application"
  default     = "safemoon"
}
