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
    random = {
      source  = "hashicorp/random"
      version = "~> 3.1"
    }
  }
}

# Generate random ID for unique naming
resource "random_id" "vm_fleet" {
  byte_length = 4
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
  name_prefix = "vm-fleet-todo-${random_id.vm_fleet.hex}"
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
    Name = "vm-fleet-todo-${random_id.vm_fleet.hex}"
  }
}

resource "aws_security_group" "alb" {
  name_prefix = "vm-fleet-alb-todo-${random_id.vm_fleet.hex}"
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
    Name = "vm-fleet-alb-todo-${random_id.vm_fleet.hex}"
  }
}

# SSH Key Pair
resource "tls_private_key" "ssh" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "vm_fleet" {
  key_name   = "vm-fleet-todo-${random_id.vm_fleet.hex}"
  public_key = tls_private_key.ssh.public_key_openssh

  tags = {
    Name = "vm-fleet-todo-${random_id.vm_fleet.hex}"
  }
}

# Launch Template
resource "aws_launch_template" "vm_fleet" {
  name_prefix   = "vm-fleet-todo-${random_id.vm_fleet.hex}"
  image_id      = data.aws_ami.ubuntu.id
  instance_type = "t3.micro"
  key_name      = aws_key_pair.vm_fleet.key_name

  vpc_security_group_ids = [aws_security_group.vm_fleet.id]

  user_data = base64encode(<<-EOF
    #!/bin/bash
    set -e
    
    # Log everything
    exec > >(tee /var/log/user-data.log) 2>&1
    echo "=== Todo App VM Setup Started at $(date) ==="
    
    # Update system
    apt-get update -y
    apt-get install -y curl git
    
    # Install Node.js 18
    curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
    apt-get install -y nodejs
    
    # Verify installation
    node --version
    npm --version
    
    # Create app user and directory
    useradd -m -s /bin/bash todoapp
    mkdir -p /home/todoapp/app
    
    # Clone the fresh todo app
    cd /home/todoapp
    git clone https://github.com/DemoKaspar/fresh-todo-app.git app
    cd app
    
    # Install dependencies
    npm install --production
    
    # Set ownership
    chown -R todoapp:todoapp /home/todoapp
    
    # Create systemd service
    cat > /etc/systemd/system/todoapp.service << 'EOL'
    [Unit]
    Description=Todo App
    After=network.target
    
    [Service]
    Type=simple
    User=todoapp
    WorkingDirectory=/home/todoapp/app
    ExecStart=/usr/bin/node server.js
    Restart=always
    RestartSec=10
    Environment=PORT=3000
    Environment=NODE_ENV=production
    
    [Install]
    WantedBy=multi-user.target
    EOL
    
    # Start service
    systemctl daemon-reload
    systemctl enable todoapp
    systemctl start todoapp
    
    # Verify it's running
    sleep 5
    systemctl status todoapp
    
    # Test health endpoint
    for i in {1..20}; do
        if curl -f http://localhost:3000/health; then
            echo "=== Todo App is healthy! ==="
            break
        fi
        echo "Waiting for app to start... ($i/20)"
        sleep 3
    done
    
    echo "=== Setup completed at $(date) ==="
  EOF
  )

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "vm-fleet-todo-${random_id.vm_fleet.hex}"
      App  = "todo-app"
      Env  = "dev"
    }
  }
}

# Auto Scaling Group
resource "aws_autoscaling_group" "vm_fleet" {
  name                = "vm-fleet-todo-${random_id.vm_fleet.hex}"
  vpc_zone_identifier = data.aws_subnets.default.ids
  target_group_arns   = [aws_lb_target_group.vm_fleet.arn]
  health_check_type   = "ELB"
  health_check_grace_period = 300

  min_size         = 2
  max_size         = 4
  desired_capacity = 2

  launch_template {
    id      = aws_launch_template.vm_fleet.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "vm-fleet-todo-${random_id.vm_fleet.hex}"
    propagate_at_launch = true
  }
}

# Application Load Balancer
resource "aws_lb" "vm_fleet" {
  name               = "vm-todo-${random_id.vm_fleet.hex}"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = data.aws_subnets.default.ids

  tags = {
    Name = "vm-fleet-todo-${random_id.vm_fleet.hex}"
  }
}

# Target Group
resource "aws_lb_target_group" "vm_fleet" {
  name     = "todo-${random_id.vm_fleet.hex}"
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
    Name = "vm-fleet-todo-${random_id.vm_fleet.hex}"
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