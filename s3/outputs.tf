output "bucket_name" {
  description = "Name of the S3 bucket"
  value       = aws_s3_bucket.main.bucket
}

output "bucket_arn" {
  description = "ARN of the S3 bucket"
  value       = aws_s3_bucket.main.arn
}

output "bucket_domain_name" {
  description = "Bucket domain name"
  value       = aws_s3_bucket.main.bucket_domain_name
}

output "region" {
  description = "AWS region where the bucket is created"
  value       = aws_s3_bucket.main.region
}

output "iam_policy_arn" {
  description = "ARN of the IAM policy for S3 access"
  value       = aws_iam_policy.s3_access.arn
}

# Common environment variables for applications
output "aws_s3_bucket" {
  description = "S3 bucket name (for AWS_S3_BUCKET env var)"
  value       = aws_s3_bucket.main.bucket
}

output "aws_region" {
  description = "AWS region (for AWS_REGION env var)"
  value       = aws_s3_bucket.main.region
}