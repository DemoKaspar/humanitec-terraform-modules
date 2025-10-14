terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

# Data sources
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
  filter {
    name   = "default-for-az"
    values = ["true"]
  }
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical
  
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
  
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Security Groups
resource "aws_security_group" "vm_fleet" {
  name_prefix = "vm-fleet-${var.app_id}-${var.env_id}"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port       = 3000
    to_port         = 3000
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/8"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "vm-fleet-${var.app_id}-${var.env_id}"
  }
}

resource "aws_security_group" "alb" {
  name_prefix = "vm-fleet-alb-${var.app_id}-${var.env_id}"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "vm-fleet-alb-${var.app_id}-${var.env_id}"
  }
}

# SSH Key Pair
resource "tls_private_key" "ssh" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "vm_fleet" {
  key_name   = "vm-fleet-${var.app_id}-${var.env_id}"
  public_key = tls_private_key.ssh.public_key_openssh

  tags = {
    Name = "vm-fleet-${var.app_id}-${var.env_id}"
  }
}

# Launch Template
resource "aws_launch_template" "vm_fleet" {
  name_prefix   = "vm-fleet-${var.app_id}-${var.env_id}"
  image_id      = data.aws_ami.ubuntu.id
  instance_type = var.instance_type
  key_name      = aws_key_pair.vm_fleet.key_name

  vpc_security_group_ids = [aws_security_group.vm_fleet.id]

  user_data = base64encode(var.startup_script)

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "vm-fleet-${var.app_id}-${var.env_id}"
      App  = var.app_id
      Env  = var.env_id
    }
  }
}

# Auto Scaling Group
resource "aws_autoscaling_group" "vm_fleet" {
  name                = "vm-fleet-${var.app_id}-${var.env_id}"
  vpc_zone_identifier = data.aws_subnets.default.ids
  target_group_arns   = [aws_lb_target_group.vm_fleet.arn]
  health_check_type   = "ELB"
  health_check_grace_period = 300

  min_size         = var.instance_count
  max_size         = var.instance_count * 2
  desired_capacity = var.instance_count

  launch_template {
    id      = aws_launch_template.vm_fleet.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "vm-fleet-${var.app_id}-${var.env_id}"
    propagate_at_launch = true
  }
}

# Application Load Balancer
resource "aws_lb" "vm_fleet" {
  name               = "vm-${substr(var.app_id, 0, 6)}-${var.env_id}"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = data.aws_subnets.default.ids

  tags = {
    Name = "vm-fleet-${var.app_id}-${var.env_id}"
  }
}

# Target Group
resource "aws_lb_target_group" "vm_fleet" {
  name     = "${substr(var.app_id, 0, 8)}-${var.env_id}"
  port     = 3000
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.default.id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 10
    interval            = 30
    path                = "/health"
    matcher             = "200"
    port                = "traffic-port"
    protocol            = "HTTP"
  }

  tags = {
    Name = "vm-fleet-${var.app_id}-${var.env_id}"
  }
}

# Listener
resource "aws_lb_listener" "vm_fleet" {
  load_balancer_arn = aws_lb.vm_fleet.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.vm_fleet.arn
  }
}