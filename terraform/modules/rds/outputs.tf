output "db_instance_id" {
  description = "RDS instance identifier"
  value       = aws_db_instance.this.id
}

output "db_endpoint" {
  description = "Connection endpoint (host:port) for the database"
  value       = aws_db_instance.this.endpoint
}

output "db_address" {
  description = "Hostname of the database instance"
  value       = aws_db_instance.this.address
}

output "db_port" {
  description = "Port the database listens on"
  value       = aws_db_instance.this.port
}

output "db_name" {
  description = "Name of the initial database created"
  value       = aws_db_instance.this.db_name
}

output "db_security_group_id" {
  description = "Security group ID attached to the RDS instance"
  value       = aws_security_group.rds.id
}

output "app_secret_arn" {
  description = "ARN of the AWS Secrets Manager secret holding DB_HOST/DB_PORT/DB_NAME/DB_USERNAME/DB_PASSWORD/REMEMBER_ME_KEY, consumed by the AutoCare Helm chart's SecretProviderClass"
  value       = aws_secretsmanager_secret.app.arn
}

output "app_secret_name" {
  description = "Name of the AWS Secrets Manager secret (autocare/<environment>/database)"
  value       = aws_secretsmanager_secret.app.name
}
