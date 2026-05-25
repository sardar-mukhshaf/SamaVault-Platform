# ---------------------------------------------------------------------------------------------------------------------
# Observability Module Outputs
# ---------------------------------------------------------------------------------------------------------------------

output "sns_topic_arn" {
  description = "ARN of the alerts SNS topic."
  value       = aws_sns_topic.alerts.arn
}

output "cloudwatch_log_group_name" {
  description = "Name of the application CloudWatch log group."
  value       = aws_cloudwatch_log_group.application.name
}

output "grafana_admin_password" {
  description = "Grafana admin password (if auto-generated)."
  value       = var.grafana_admin_password == null && var.enable_grafana ? random_password.grafana[0].result : var.grafana_admin_password
  sensitive   = true
}

output "pagerduty_integration_key" {
  description = "PagerDuty integration key for CloudWatch."
  value       = var.pagerduty_service_name != null ? pagerduty_service_integration.cloudwatch[0].integration_key : null
  sensitive   = true
}
