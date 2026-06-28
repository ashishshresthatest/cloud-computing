# Terraform for Module 07
##############################################################################
# You will need to fill in the blank values using the values in terraform.tfvars
# or using the links to the documentation. You can also make use of the auto-complete
# in VSCode
# Reference your code in Module 04 to fill out the values
# This is the same exercise but converting from Bash to HCL
##############################################################################
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/vpc
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/vpcs
##############################################################################
# Terraform for Module 07

data "aws_vpc" "main" {
  default = true
}

output "vpcs" {
  value = data.aws_vpc.main.id
}

data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_availability_zones" "primary" {
  filter {
    name   = "zone-name"
    values = ["us-east-2a"]
  }
}

data "aws_availability_zones" "secondary" {
  filter {
    name   = "zone-name"
    values = ["us-east-2b"]
  }
}

data "aws_subnets" "subneta" {
  filter {
    name   = "availability-zone"
    values = ["us-east-2a"]
  }
}

data "aws_subnets" "subnetb" {
  filter {
    name   = "availability-zone"
    values = ["us-east-2b"]
  }
}

data "aws_subnets" "subnetc" {
  filter {
    name   = "availability-zone"
    values = ["us-east-2c"]
  }
}

output "subnetid-2a" {
  value = data.aws_subnets.subneta.ids
}

resource "aws_lb" "lb" {
  name               = var.elb-name
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.vpc_security_group_ids]
  subnets            = [data.aws_subnets.subneta.ids[0], data.aws_subnets.subnetb.ids[0]]

  enable_deletion_protection = false

  tags = {
    Environment = "production"
  }
}

output "url" {
  value = aws_lb.lb.dns_name
}

resource "aws_lb_target_group" "alb-lb-tg" {
  depends_on  = [aws_lb.lb]
  name        = var.tg-name
  target_type = "instance"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = data.aws_vpc.main.id
}

resource "aws_lb_listener" "front_end" {
  load_balancer_arn = aws_lb.lb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.alb-lb-tg.arn
  }
}

resource "aws_launch_template" "mp1-lt" {
  name                                 = var.lt-name
  image_id                             = var.imageid
  instance_initiated_shutdown_behavior = "terminate"
  instance_type                        = var.instance-type
  key_name                             = var.key-name

  monitoring {
    enabled = false
  }

  placement {
    availability_zone = "us-east-2a"
  }

  block_device_mappings {
    device_name = "/dev/sda1"

    ebs {
      volume_size = 8
    }
  }

  block_device_mappings {
    device_name = "/dev/sdc"

    ebs {
      volume_size = 15
    }
  }

  network_interfaces {
    subnet_id        = data.aws_subnets.subneta.ids[0]
    security_groups  = [var.vpc_security_group_ids]
    associate_public_ip_address = true
  }

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name       = var.module-tag
      assessment = var.module-tag
    }
  }

  user_data = filebase64("./install-env.sh")
}

resource "aws_autoscaling_group" "bar" {
  name                      = var.asg-name
  depends_on                = [aws_launch_template.mp1-lt]
  desired_capacity          = var.cnt
  max_size                  = 5
  min_size                  = 2
  health_check_grace_period = 300
  health_check_type         = "ELB"
  target_group_arns         = [aws_lb_target_group.alb-lb-tg.arn]
  vpc_zone_identifier       = [data.aws_subnets.subneta.ids[0], data.aws_subnets.subnetb.ids[0]]

  tag {
    key                 = "assessment"
    value               = var.module-tag
    propagate_at_launch = true
  }

  tag {
    key                 = "Name"
    value               = var.module-tag
    propagate_at_launch = true
  }

  launch_template {
    id      = aws_launch_template.mp1-lt.id
    version = "$Latest"
  }
}

resource "aws_autoscaling_attachment" "example" {
  depends_on             = [aws_lb.lb]
  autoscaling_group_name = aws_autoscaling_group.bar.name
  lb_target_group_arn    = aws_lb_target_group.alb-lb-tg.arn
}

output "alb-lb-tg-arn" {
  value = aws_lb_target_group.alb-lb-tg.arn
}

output "alb-lb-tg-id" {
  value = aws_lb_target_group.alb-lb-tg.id
}