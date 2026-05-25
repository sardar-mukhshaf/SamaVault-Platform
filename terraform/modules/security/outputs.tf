# ---------------------------------------------------------------------------------------------------------------------
# Security Module Outputs
# ---------------------------------------------------------------------------------------------------------------------

output "kms_key_id" {
  description = "The ID of the KMS CMK."
  value       = aws_kms_key.main.key_id
}

output "kms_key_arn" {
  description = "The ARN of the KMS CMK."
  value       = aws_kms_key.main.arn
  sensitive   = true
}

output "kms_alias_name" {
  description = "The alias of the KMS CMK."
  value       = aws_kms_alias.main.name
}

output "waf_web_acl_arn" {
  description = "The ARN of the WAFv2 WebACL."
  value       = aws_wafv2_web_acl.main.arn
}

output "waf_web_acl_id" {
  description = "The ID of the WAFv2 WebACL."
  value       = aws_wafv2_web_acl.main.id
}

output "guardduty_detector_id" {
  description = "The ID of the GuardDuty detector."
  value       = var.enable_guardduty ? aws_guardduty_detector.main[0].id : null
}

output "security_hub_enabled" {
  description = "Whether Security Hub is enabled."
  value       = var.enable_security_hub
}

output "shield_protection_id" {
  description = "The ID of the Shield Advanced protection (requires ALB ARN)."
  value       = null
}
