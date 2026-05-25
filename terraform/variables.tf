# ---------------------------------------------------------------------------------------------------------------------
# Global Variables
# All values are driven exclusively from terraform.tfvars and environment-specific *.tfvars files.
# ---------------------------------------------------------------------------------------------------------------------

# ---------------------------------------------------------------------------------------------------------------------
# General / Environment
# ---------------------------------------------------------------------------------------------------------------------

variable "project_name" {
  description = "Name of the project used for resource naming and tagging."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,29}$", var.project_name))
    error_message = "Project name must be lowercase alphanumeric with hyphens, 3-30 chars, starting with a letter."
  }
}

variable "environment" {
  description = "Deployment environment. Must be one of: dev, staging, prod."
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "common_tags" {
  description = "Common tags applied to all resources."
  type        = map(string)
  default     = {}
}

variable "primary_region" {
  description = "Primary AWS region for deployment (e.g., me-central-1 for Riyadh)."
  type        = string

  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]+-[0-9]$", var.primary_region))
    error_message = "Primary region must be a valid AWS region format."
  }
}

variable "secondary_region" {
  description = "Secondary AWS region for DR / multi-region replication (e.g., me-central-2 for Dubai)."
  type        = string

  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]+-[0-9]$", var.secondary_region))
    error_message = "Secondary region must be a valid AWS region format."
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# Networking
# ---------------------------------------------------------------------------------------------------------------------

variable "networking" {
  description = "Networking module configuration."
  type = object({
    cidr_blocks              = map(string)
    availability_zones       = list(string)
    enable_transit_gateway   = bool
    peer_region_vpc_id       = optional(string, null)
    nat_gateway_per_az       = optional(bool, true)
    enable_vpc_flow_logs     = optional(bool, true)
    flow_logs_retention_days = optional(number, 2555)
  })

  validation {
    condition     = length(var.networking.availability_zones) >= 2
    error_message = "At least 2 availability zones must be specified for HA."
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# EKS
# ---------------------------------------------------------------------------------------------------------------------

variable "eks" {
  description = "EKS module configuration."
  type = object({
    cluster_version          = string
    node_instance_types      = list(string)
    desired_capacity         = number
    min_capacity             = optional(number, 1)
    max_capacity             = optional(number, 10)
    enable_karpenter         = optional(bool, false)
    enable_private_endpoint  = optional(bool, true)
    enable_public_endpoint   = optional(bool, false)
    bastion_instance_type    = optional(string, "t3.micro")
    enable_bastion           = optional(bool, true)
  })

  validation {
    condition     = can(regex("^1\\.(2[9]|[3-9][0-9])$", var.eks.cluster_version))
    error_message = "EKS cluster version must be 1.29 or higher."
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# Security
# ---------------------------------------------------------------------------------------------------------------------

variable "security" {
  description = "Security module configuration."
  type = object({
    allowed_countries        = list(string)
    waf_rate_limit           = number
    enable_shield_advanced   = bool
    enable_guardduty         = optional(bool, true)
    enable_security_hub      = optional(bool, true)
    kms_multi_region         = optional(bool, true)
    enable_waf_logging       = optional(bool, true)
  })

  validation {
    condition     = length(var.security.allowed_countries) > 0
    error_message = "At least one allowed country must be specified for WAF geo-blocking."
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# Compliance
# ---------------------------------------------------------------------------------------------------------------------

variable "compliance" {
  description = "Compliance module configuration (SAMA simulation)."
  type = object({
    audit_retention_years    = number
    enable_object_lock       = bool
    compliance_bucket_name   = optional(string, null)
    enable_cloudtrail        = optional(bool, true)
    enable_config            = optional(bool, true)
    mfa_delete               = optional(bool, true)
  })

  validation {
    condition     = var.compliance.audit_retention_years >= 7
    error_message = "SAMA compliance requires a minimum of 7 years audit retention."
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# Observability
# ---------------------------------------------------------------------------------------------------------------------

variable "observability" {
  description = "Observability module configuration."
  type = object({
    datadog_api_key_secret_arn = optional(string, null)
    pagerduty_service_name     = optional(string, null)
    alert_email                = optional(string, null)
    enable_prometheus          = optional(bool, true)
    enable_grafana             = optional(bool, true)
    enable_cloudwatch_insights = optional(bool, true)
    grafana_admin_password     = optional(string, null)
  })
}

# ---------------------------------------------------------------------------------------------------------------------
# GitOps
# ---------------------------------------------------------------------------------------------------------------------

variable "gitops" {
  description = "GitOps module configuration."
  type = object({
    argocd_version      = string
    gitops_repo_url     = string
    target_revision     = optional(string, "main")
    enable_auto_sync    = optional(bool, true)
    enable_prune        = optional(bool, true)
    enable_self_heal    = optional(bool, true)
    notifications_enabled = optional(bool, true)
    notification_channel = optional(string, "slack")
  })

  validation {
    condition     = can(regex("^https?://", var.gitops.gitops_repo_url))
    error_message = "GitOps repo URL must be a valid HTTP(S) URL."
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# Database
# ---------------------------------------------------------------------------------------------------------------------

variable "database" {
  description = "Database module configuration."
  type = object({
    db_instance_class           = string
    db_name                     = string
    db_username                 = optional(string, "dbadmin")
    backup_retention            = number
    enable_performance_insights = optional(bool, true)
    multi_az                    = optional(bool, true)
    storage_encrypted           = optional(bool, true)
    deletion_protection         = optional(bool, true)
    skip_final_snapshot         = optional(bool, false)
  })

  validation {
    condition     = var.database.backup_retention >= 7
    error_message = "Production databases require at least 7 days of backup retention."
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# State Backend
# ---------------------------------------------------------------------------------------------------------------------

variable "state_backend" {
  description = "State backend configuration."
  type = object({
    bucket_name         = string
    dynamodb_table_name = string
    state_key_prefix    = optional(string, "terraform/state")
  })
}
