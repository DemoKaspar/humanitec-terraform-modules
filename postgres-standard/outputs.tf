output "connection_string" {
  description = "Full database connection string"
  value       = "postgresql://${aws_db_instance.postgres.username}:${aws_db_instance.postgres.password}@${aws_db_instance.postgres.endpoint}/${aws_db_instance.postgres.db_name}"
  sensitive   = true
}

output "hostname" {
  description = "Database hostname"
  value       = aws_db_instance.postgres.address
}

output "port" {
  description = "Database port"
  value       = aws_db_instance.postgres.port
}

output "database" {
  description = "Database name"
  value       = aws_db_instance.postgres.db_name
}

output "username" {
  description = "Database username"
  value       = aws_db_instance.postgres.username
}

output "password" {
  description = "Database password"
  value       = aws_db_instance.postgres.password
  sensitive   = true
}

output "endpoint" {
  description = "Database endpoint"
  value       = aws_db_instance.postgres.endpoint
}

output "instance_class" {
  description = "Database instance class (for reference)"
  value       = aws_db_instance.postgres.instance_class
}

output "allocated_storage" {
  description = "Allocated storage size (for reference)"
  value       = aws_db_instance.postgres.allocated_storage
}