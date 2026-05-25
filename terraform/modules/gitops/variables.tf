# ---------------------------------------------------------------------------------------------------------------------
# GitOps Module Variables
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

variable "argocd_version" {
  type = string
}

variable "gitops_repo_url" {
  type = string
}

variable "target_revision" {
  type    = string
  default = "main"
}

variable "enable_auto_sync" {
  type    = bool
  default = true
}

variable "enable_prune" {
  type    = bool
  default = true
}

variable "enable_self_heal" {
  type    = bool
  default = true
}

variable "notifications_enabled" {
  type    = bool
  default = true
}

variable "notification_channel" {
  type    = string
  default = "slack"
}

variable "eks_cluster_name" {
  type = string
}

variable "eks_oidc_issuer_url" {
  type = string
}

variable "eks_oidc_provider_arn" {
  type = string
}
