# ---------------------------------------------------------------------------------------------------------------------
# Staging Environment Variables
# ---------------------------------------------------------------------------------------------------------------------

project_name = "saudi-bank-backend"
environment  = "staging"

common_tags = {
  Project     = "saudi-bank-backend"
  Environment = "staging"
  ManagedBy   = "terraform"
  Owner       = "platform-team"
  CostCenter  = "engineering"
}

primary_region   = "me-central-1"
secondary_region = "me-central-2"

# ---------------------------------------------------------------------------------------------------------------------
# Networking
# ---------------------------------------------------------------------------------------------------------------------

networking = {
  cidr_blocks = {
    vpc      = "10.1.0.0/16"
    public   = "10.1.0.0/20"
    private  = "10.1.16.0/20"
    database = "10.1.32.0/20"
  }
  availability_zones       = ["me-central-1a", "me-central-1b", "me-central-1c"]
  enable_transit_gateway   = false
  peer_region_vpc_id       = null
  nat_gateway_per_az       = true
  enable_vpc_flow_logs     = true
  flow_logs_retention_days = 2555
}

# ---------------------------------------------------------------------------------------------------------------------
# EKS
# ---------------------------------------------------------------------------------------------------------------------

eks = {
  cluster_version         = "1.29"
  node_instance_types     = ["t3.large"]
  desired_capacity        = 3
  min_capacity            = 2
  max_capacity            = 6
  enable_karpenter        = true
  enable_private_endpoint = true
  enable_public_endpoint  = false
  bastion_instance_type   = "t3.micro"
  enable_bastion          = true
}

# ---------------------------------------------------------------------------------------------------------------------
# Security
# ---------------------------------------------------------------------------------------------------------------------

security = {
  allowed_countries      = ["SA", "AE"]
  waf_rate_limit         = 3000
  enable_shield_advanced = false
  enable_guardduty       = true
  enable_security_hub    = true
  kms_multi_region       = true
  enable_waf_logging     = true
}

# ---------------------------------------------------------------------------------------------------------------------
# Compliance
# ---------------------------------------------------------------------------------------------------------------------

compliance = {
  audit_retention_years  = 7
  enable_object_lock     = true
  compliance_bucket_name = null
  enable_cloudtrail      = true
  enable_config          = true
  mfa_delete             = false
}

# ---------------------------------------------------------------------------------------------------------------------
# Observability
# ---------------------------------------------------------------------------------------------------------------------

observability = {
  datadog_api_key_secret_arn = null
  pagerduty_service_name     = "saudi-bank-staging"
  alert_email                = "staging-alerts@example.com"
  enable_prometheus          = true
  enable_grafana             = true
  enable_cloudwatch_insights = true
  grafana_admin_password     = null
}

# ---------------------------------------------------------------------------------------------------------------------
# GitOps
# ---------------------------------------------------------------------------------------------------------------------

gitops = {
  argocd_version        = "5.51.6"
  gitops_repo_url       = "https://github.com/your-org/saudi-bank-backend.git"
  target_revision       = "main"
  enable_auto_sync      = true
  enable_prune          = true
  enable_self_heal      = true
  notifications_enabled = true
  notification_channel  = "slack"
}

# ---------------------------------------------------------------------------------------------------------------------
# Database
# ---------------------------------------------------------------------------------------------------------------------

database = {
  db_instance_class           = "db.r6g.large"
  db_name                     = "banking_staging"
  db_username                 = "dbadmin"
  backup_retention            = 14
  enable_performance_insights = true
  multi_az                    = true
  storage_encrypted           = true
  deletion_protection         = true
  skip_final_snapshot         = false
}

# ---------------------------------------------------------------------------------------------------------------------
# State Backend
# ---------------------------------------------------------------------------------------------------------------------

state_backend = {
  bucket_name         = "saudi-bank-backend-tfstate-staging"
  dynamodb_table_name = "saudi-bank-backend-tflock-staging"
  state_key_prefix    = "terraform/staging"
}
