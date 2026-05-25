# ---------------------------------------------------------------------------------------------------------------------
# Security Module Variables
# ---------------------------------------------------------------------------------------------------------------------

variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "common_tags" {
  type    = map(string)
  default = {}
}

variable "name_prefix" {
  type = string
}

variable "primary_region" {
  type = string
}

variable "allowed_countries" {
  description = "List of ISO 3166-1 alpha-2 country codes to allow in WAF."
  type        = list(string)
}

variable "waf_rate_limit" {
  description = "Rate limit per 5 minutes per IP for WAF."
  type        = number
}

variable "enable_shield_advanced" {
  type = bool
}

variable "enable_guardduty" {
  type    = bool
  default = true
}

variable "enable_security_hub" {
  type    = bool
  default = true
}

variable "kms_multi_region" {
  type    = bool
  default = true
}

variable "enable_waf_logging" {
  type    = bool
  default = true
}

variable "compliance_audit_bucket_name" {
  type = string
}

variable "compliance_audit_bucket_arn" {
  type = string
}

variable "vpc_id" {
  type = string
}
