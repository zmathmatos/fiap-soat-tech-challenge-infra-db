output "endpoint" {
  description = "RDS instance endpoint"
  value       = aws_db_instance.main.endpoint
}

output "address" {
  description = "RDS instance address"
  value       = aws_db_instance.main.address
}

output "port" {
  description = "RDS instance port"
  value       = var.port
}

output "database_name" {
  description = "Database name"
  value       = aws_db_instance.main.db_name
}

output "master_username" {
  description = "Master username"
  value       = aws_db_instance.main.username
  sensitive   = true
}

output "id" {
  description = "RDS instance ID"
  value       = aws_db_instance.main.id
}

output "arn" {
  description = "RDS instance ARN"
  value       = aws_db_instance.main.arn
}

output "security_group_id" {
  description = "Security group ID"
  value       = aws_security_group.rds.id
}

output "connection_string" {
  description = "PostgreSQL connection string"
  value       = "postgresql://${var.master_username}:${var.master_password}@${aws_db_instance.main.address}:${var.port}/${aws_db_instance.main.db_name}"
  sensitive   = true
}
