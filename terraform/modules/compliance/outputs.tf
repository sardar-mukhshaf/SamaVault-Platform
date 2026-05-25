# ---------------------------------------------------------------------------------------------------------------------
# Compliance Module Outputs
# ---------------------------------------------------------------------------------------------------------------------

output "audit_bucket_name" {
  description = "Name of the centralized audit S3 bucket."
  value       = aws_s3_bucket.audit.id
}

output "audit_bucket_arn" {
  description = "ARN of the centralized audit S3 bucket."
  value       = aws_s3_bucket.audit.arn
}

output "cloudtrail_name" {
  description = "Name of the CloudTrail trail."
  value       = var.enable_cloudtrail ? aws_cloudtrail.main[0].id : null
}

output "config_recorder_name" {
  description = "Name of the AWS Config recorder."
  value       = var.enable_config ? aws_config_configuration_recorder.main[0].name : null
}
