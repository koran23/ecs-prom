locals {
  name = "${var.name}-${var.env}-${terraform.workspace}"


  ec2_instances_monitoring = {

    instances = {
      local.name = {
        ami_id                      = try(var.ami_id, data.aws_ami.latest_amazon_linux.id)
        vpc_id                      = data.aws_vpc.vpc.id # either vpc_id or vpc_name
        ami_name                    = ""                  # either ami_id or ami_name 
        associate_public_ip_address = true
        create_eip                  = true
        delete_on_termination       = true

        # Creates route53 A record with the following pattern. each.key represents the index of the resource_keys
        # "${var.name}-${each.key}.${var.domain_name}"
        # types can be public or private 
        dns = {
          create = false
          type   = "public"
        }
        ebs_optimized               = true
        iam_instance_profile        = "monitoringEC2Role"
        instance_type               = "t3.large"
        key_name                    = var.key_name
        root_vol_size               = "50"
        root_vol_type               = "gp3"
        subnet_id                   = data.aws_subnets.public_subnets_ids.ids[0]
        attached_volume             = false
        attached_volume_device_name = ""

        # resource_keys is used to created instances based on the number of strings in the associated list.
        # We do this so terraform associates the instance with a mapped string value rather than an index ( numeric ). 
        # This allows for control of the lifecycle for each specific instance. If you need more than one instance of the same 
        # type consider using an autoscaling group :)
        resource_keys = var.resource_keys

      },
    }
  }

  ec2_security_group_monitoring = {

    allow_all = true # allow all outbound traffic

    name = local.name

    description = "EC2 security group for ${local.name}"

    inbound_ports = [
      {
        from_port   = 22
        to_port     = 22
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
      },
      {
        from_port   = 3000
        to_port     = 3000
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
      },
      {
        from_port   = 9090
        to_port     = 9090
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
      },

    ]
    outbound_ports = []
  }

}
