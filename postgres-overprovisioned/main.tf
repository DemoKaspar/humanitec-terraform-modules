terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.1"
    }
  }
}

# Generate random ID and password
resource "random_id" "db" {
  byte_length = 4
}

resource "random_password" "db_password" {
  length  = 16
  special = true
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
}

# DB Subnet Group
resource "aws_db_subnet_group" "postgres" {
  name       = "postgres-overprovisioned-${random_id.db.hex}"
  subnet_ids = data.aws_subnets.default.ids

  tags = {
    Name = "postgres-overprovisioned-${random_id.db.hex}"
    Type = "overprovisioned"
  }
}

# Security Group for RDS
resource "aws_security_group" "postgres" {
  name_prefix = "postgres-overprovisioned-${random_id.db.hex}"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.default.cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "postgres-overprovisioned-${random_id.db.hex}"
    Type = "overprovisioned"
  }
}

# RDS PostgreSQL Instance - OVERPROVISIONED
resource "aws_db_instance" "postgres" {
  identifier = "postgres-overprovisioned-${random_id.db.hex}"

  # Engine configuration
  engine         = "postgres"
  engine_version = "15.8"
  instance_class = "db.t3.small"  # OVERPROVISIONED - larger than needed

  # Database configuration
  db_name  = "appdb"
  username = "appuser"
  password = random_password.db_password.result

  # Storage configuration - OVERPROVISIONED
  allocated_storage     = 100   # OVERPROVISIONED - much larger than needed
  max_allocated_storage = 200   # OVERPROVISIONED
  storage_type          = "gp3" # OVERPROVISIONED - faster storage
  storage_encrypted     = true

  # Network configuration
  db_subnet_group_name   = aws_db_subnet_group.postgres.name
  vpc_security_group_ids = [aws_security_group.postgres.id]
  publicly_accessible    = false

  # Backup and maintenance - OVERPROVISIONED
  backup_retention_period = 14  # OVERPROVISIONED - longer retention
  backup_window          = "03:00-04:00"
  maintenance_window     = "sun:04:00-sun:05:00"

  # Performance and monitoring - OVERPROVISIONED
  performance_insights_enabled = true  # OVERPROVISIONED - enabled
  monitoring_interval         = 0      # Disabled to avoid IAM role requirement

  # Deletion protection (disabled for dev environments)
  deletion_protection = false
  skip_final_snapshot = true

  tags = {
    Name = "postgres-overprovisioned-${random_id.db.hex}"
    Type = "overprovisioned"
  }
}