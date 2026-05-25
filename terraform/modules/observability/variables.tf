# ---------------------------------------------------------------------------------------------------------------------
# Observability Module Variables
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

variable "datadog_api_key_secret_arn" {
  type    = string
  default = null
}

variable "pagerduty_service_name" {
  type    = string
  default = null
}

variable "alert_email" {
  type    = string
  default = null
}

variable "enable_prometheus" {
  type    = bool
  default = true
}

variable "enable_grafana" {
  type    = bool
  default = true
}

variable "enable_cloudwatch_insights" {
  type    = bool
  default = true
}

variable "grafana_admin_password" {
  type      = string
  default   = null
  sensitive = true
}

variable "eks_cluster_name" {
  type = string
}

variable "eks_cluster_id" {
  type = string
}

variable "kms_key_arn" {
  type = string
}
