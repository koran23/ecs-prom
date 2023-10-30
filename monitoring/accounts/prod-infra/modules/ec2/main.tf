provider "aws" {
  region = "us-east-1"
}

module "ec2_monitoring" {
  source = "git::git@github.com:Safemoon-Protocol/Terraform.git//modules/ec2-generic?ref=master"

  for_each = local.ec2_instances_monitoring.instances

  domain_name    = var.domain_name
  ec2_instance   = each.value
  name           = each.key
  security_group = local.ec2_security_group_monitoring
  tags           = var.tags
  user_data = templatefile("${path.module}/templates/user_data.sh", {
    attached_volume             = each.value.attached_volume
    attached_volume_device_name = each.value.attached_volume_device_name
  })
  region = var.region
}
