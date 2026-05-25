# ---------------------------------------------------------------------------------------------------------------------
# Database Module Outputs
# ---------------------------------------------------------------------------------------------------------------------

output "db_instance_id" {
  description = "The RDS instance ID."
  value       = aws_db_instance.main.id
}

output "db_instance_address" {
  description = "The address of the RDS instance."
  value       = aws_db_instance.main.address
  sensitive   = true
}

output "db_instance_endpoint" {
  description = "The endpoint of the RDS instance."
  value       = aws_db_instance.main.endpoint
  sensitive   = true
}

output "db_instance_arn" {
  description = "The ARN of the RDS instance."
  value       = aws_db_instance.main.arn
}

output "secret_arn" {
  description = "ARN of the Secrets Manager secret for DB credentials."
  value       = aws_secretsmanager_secret.db_credentials.arn
}

output "secret_name" {
  description = "Name of the Secrets Manager secret."
  value       = aws_secretsmanager_secret.db_credentials.name
}
