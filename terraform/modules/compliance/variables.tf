# ---------------------------------------------------------------------------------------------------------------------
# Compliance Module Variables
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

variable "audit_retention_years" {
  description = "Number of years to retain audit logs (minimum 7 for SAMA)."
  type        = number
}

variable "enable_object_lock" {
  description = "Enable S3 Object Lock in COMPLIANCE mode."
  type        = bool
}

variable "compliance_bucket_name" {
  description = "Override name for the compliance bucket. Auto-generated if null."
  type        = string
  default     = null
}

variable "enable_cloudtrail" {
  type    = bool
  default = true
}

variable "enable_config" {
  type    = bool
  default = true
}

variable "mfa_delete" {
  type    = bool
  default = true
}

variable "kms_key_arn" {
  description = "ARN of the KMS key for encryption."
  type        = string
}

variable "vpc_id" {
  type = string
}
