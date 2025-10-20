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

# Generate random ID for unique bucket naming
resource "random_id" "bucket" {
  byte_length = 4
}

# S3 Bucket
resource "aws_s3_bucket" "main" {
  bucket = "fresh-todo-app-${random_id.bucket.hex}"

  tags = {
    Name        = "fresh-todo-app-${random_id.bucket.hex}"
    Project     = "fresh-todo-app"
    Environment = "dev"
    ManagedBy   = "humanitec-platform"
  }
}

# S3 Bucket Versioning
resource "aws_s3_bucket_versioning" "main" {
  bucket = aws_s3_bucket.main.id
  versioning_configuration {
    status = "Enabled"
  }
}

# S3 Bucket Server Side Encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "main" {
  bucket = aws_s3_bucket.main.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# S3 Bucket Public Access Block (Security best practice)
resource "aws_s3_bucket_public_access_block" "main" {
  bucket = aws_s3_bucket.main.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# IAM Policy for application access
resource "aws_iam_policy" "s3_access" {
  name        = "fresh-todo-app-s3-access-${random_id.bucket.hex}"
  path        = "/"
  description = "IAM policy for S3 access for fresh-todo-app"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Effect = "Allow"
        Resource = [
          aws_s3_bucket.main.arn,
          "${aws_s3_bucket.main.arn}/*"
        ]
      }
    ]
  })
}