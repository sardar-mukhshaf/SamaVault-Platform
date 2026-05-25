# ---------------------------------------------------------------------------------------------------------------------
# Providers Configuration
# Multi-region setup for Riyadh (me-central-1) and Dubai (me-central-2) with aliases.
# ---------------------------------------------------------------------------------------------------------------------

terraform {
  required_version = ">= 1.7.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.25"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.12"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.4"
    }
    pagerduty = {
      source  = "pagerduty/pagerduty"
      version = "~> 3.6"
    }
  }
}

# Primary provider for the target region (configurable via var.primary_region)
provider "aws" {
  region = var.primary_region

  default_tags {
    tags = var.common_tags
  }
}

# Secondary provider for disaster recovery / multi-region replication
provider "aws" {
  alias  = "secondary"
  region = var.secondary_region

  default_tags {
    tags = var.common_tags
  }
}

# Provider for us-east-1 (required for CloudFront, WAF, Shield, Global Accelerator, etc.)
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"

  default_tags {
    tags = var.common_tags
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# Kubernetes & Helm Providers
# These are configured to use the EKS cluster after it is created.
# For the initial deployment, run terraform apply with -target=module.eks first,
# then configure kubeconfig and run the full apply.
# ---------------------------------------------------------------------------------------------------------------------

provider "kubernetes" {
  # Configure via environment variables or kubeconfig file after cluster creation:
  # export KUBE_CONFIG_PATH=~/.kube/config
}

provider "helm" {
  kubernetes {
    # Configure via environment variables or kubeconfig file after cluster creation:
    # export KUBE_CONFIG_PATH=~/.kube/config
  }
}

# PagerDuty provider
provider "pagerduty" {
  # PAGERDUTY_TOKEN environment variable required
}
