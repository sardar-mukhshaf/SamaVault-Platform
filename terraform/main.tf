# ---------------------------------------------------------------------------------------------------------------------
# Main Orchestrator
# Conditionally calls all modules based on the environment and variable inputs.
# ---------------------------------------------------------------------------------------------------------------------

locals {
  environment_suffix = var.environment == "prod" ? "" : "-${var.environment}"
  name_prefix        = "${var.project_name}${local.environment_suffix}"

  is_prod = var.environment == "prod"
}

# ---------------------------------------------------------------------------------------------------------------------
# Data Sources
# ---------------------------------------------------------------------------------------------------------------------

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
data "aws_availability_zones" "available" {
  state = "available"
}

# ---------------------------------------------------------------------------------------------------------------------
# Networking Module
# ---------------------------------------------------------------------------------------------------------------------

module "networking" {
  source = "./modules/networking"

  project_name     = var.project_name
  environment      = var.environment
  common_tags      = var.common_tags
  name_prefix      = local.name_prefix
  primary_region   = var.primary_region
  secondary_region = var.secondary_region

  cidr_blocks              = var.networking.cidr_blocks
  availability_zones       = coalesce(var.networking.availability_zones, slice(data.aws_availability_zones.available.names, 0, 3))
  enable_transit_gateway   = var.networking.enable_transit_gateway
  peer_region_vpc_id       = var.networking.peer_region_vpc_id
  nat_gateway_per_az       = var.networking.nat_gateway_per_az
  enable_vpc_flow_logs     = var.networking.enable_vpc_flow_logs
  flow_logs_retention_days = var.networking.flow_logs_retention_days
}

# ---------------------------------------------------------------------------------------------------------------------
# Security Module
# ---------------------------------------------------------------------------------------------------------------------

module "security" {
  source = "./modules/security"

  project_name   = var.project_name
  environment    = var.environment
  common_tags    = var.common_tags
  name_prefix    = local.name_prefix
  primary_region = var.primary_region

  allowed_countries      = var.security.allowed_countries
  waf_rate_limit         = var.security.waf_rate_limit
  enable_shield_advanced = var.security.enable_shield_advanced
  enable_guardduty       = var.security.enable_guardduty
  enable_security_hub    = var.security.enable_security_hub
  kms_multi_region       = var.security.kms_multi_region
  enable_waf_logging     = var.security.enable_waf_logging

  compliance_audit_bucket_name = module.compliance.audit_bucket_name
  compliance_audit_bucket_arn  = module.compliance.audit_bucket_arn
  vpc_id                       = module.networking.vpc_id
}

# ---------------------------------------------------------------------------------------------------------------------
# Compliance Module (SAMA Simulation)
# ---------------------------------------------------------------------------------------------------------------------

module "compliance" {
  source = "./modules/compliance"

  project_name   = var.project_name
  environment    = var.environment
  common_tags    = var.common_tags
  name_prefix    = local.name_prefix
  primary_region = var.primary_region

  audit_retention_years  = var.compliance.audit_retention_years
  enable_object_lock     = var.compliance.enable_object_lock
  compliance_bucket_name = var.compliance.compliance_bucket_name
  enable_cloudtrail      = var.compliance.enable_cloudtrail
  enable_config          = var.compliance.enable_config
  mfa_delete             = var.compliance.mfa_delete
  kms_key_arn            = module.security.kms_key_arn
  vpc_id                 = module.networking.vpc_id
}

# ---------------------------------------------------------------------------------------------------------------------
# Database Module
# ---------------------------------------------------------------------------------------------------------------------

module "database" {
  source = "./modules/database"

  project_name   = var.project_name
  environment    = var.environment
  common_tags    = var.common_tags
  name_prefix    = local.name_prefix
  primary_region = var.primary_region

  db_instance_class           = var.database.db_instance_class
  db_name                     = var.database.db_name
  db_username                 = var.database.db_username
  backup_retention            = var.database.backup_retention
  enable_performance_insights = var.database.enable_performance_insights
  multi_az                    = var.database.multi_az
  storage_encrypted           = var.database.storage_encrypted
  deletion_protection         = var.database.deletion_protection
  skip_final_snapshot         = var.database.skip_final_snapshot
  kms_key_id                  = module.security.kms_key_arn
  database_subnet_group_name  = module.networking.database_subnet_group_name
  database_subnet_ids         = module.networking.database_subnet_ids
  vpc_id                      = module.networking.vpc_id
  allowed_cidr_blocks         = [var.networking.cidr_blocks["vpc"]]
}

# ---------------------------------------------------------------------------------------------------------------------
# EKS Module
# ---------------------------------------------------------------------------------------------------------------------

module "eks" {
  source = "./modules/eks"

  project_name   = var.project_name
  environment    = var.environment
  common_tags    = var.common_tags
  name_prefix    = local.name_prefix
  primary_region = var.primary_region

  cluster_version         = var.eks.cluster_version
  node_instance_types     = var.eks.node_instance_types
  desired_capacity        = var.eks.desired_capacity
  min_capacity            = var.eks.min_capacity
  max_capacity            = var.eks.max_capacity
  enable_karpenter        = var.eks.enable_karpenter
  enable_private_endpoint = var.eks.enable_private_endpoint
  enable_public_endpoint  = var.eks.enable_public_endpoint
  bastion_instance_type   = var.eks.bastion_instance_type
  enable_bastion          = var.eks.enable_bastion
  kms_key_arn             = module.security.kms_key_arn
  vpc_id                  = module.networking.vpc_id
  private_subnet_ids      = module.networking.private_subnet_ids
  public_subnet_ids       = module.networking.public_subnet_ids
}

# ---------------------------------------------------------------------------------------------------------------------
# Observability Module
# ---------------------------------------------------------------------------------------------------------------------

module "observability" {
  source = "./modules/observability"

  project_name   = var.project_name
  environment    = var.environment
  common_tags    = var.common_tags
  name_prefix    = local.name_prefix
  primary_region = var.primary_region

  datadog_api_key_secret_arn = var.observability.datadog_api_key_secret_arn
  pagerduty_service_name     = var.observability.pagerduty_service_name
  alert_email                = var.observability.alert_email
  enable_prometheus          = var.observability.enable_prometheus
  enable_grafana             = var.observability.enable_grafana
  enable_cloudwatch_insights = var.observability.enable_cloudwatch_insights
  grafana_admin_password     = var.observability.grafana_admin_password
  eks_cluster_name           = module.eks.cluster_name
  eks_cluster_id             = module.eks.cluster_id
  kms_key_arn                = module.security.kms_key_arn
}

# ---------------------------------------------------------------------------------------------------------------------
# GitOps Module
# ---------------------------------------------------------------------------------------------------------------------

module "gitops" {
  source = "./modules/gitops"

  project_name   = var.project_name
  environment    = var.environment
  common_tags    = var.common_tags
  name_prefix    = local.name_prefix
  primary_region = var.primary_region

  argocd_version         = var.gitops.argocd_version
  gitops_repo_url        = var.gitops.gitops_repo_url
  target_revision        = var.gitops.target_revision
  enable_auto_sync       = var.gitops.enable_auto_sync
  enable_prune           = var.gitops.enable_prune
  enable_self_heal       = var.gitops.enable_self_heal
  notifications_enabled  = var.gitops.notifications_enabled
  notification_channel   = var.gitops.notification_channel
  eks_cluster_name       = module.eks.cluster_name
  eks_oidc_issuer_url    = module.eks.oidc_issuer_url
  eks_oidc_provider_arn  = module.eks.oidc_provider_arn
}
