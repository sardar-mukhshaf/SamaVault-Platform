# ---------------------------------------------------------------------------------------------------------------------
# Makefile for Saudi Bank Backend Infrastructure
# Standardizes Terraform and deployment commands across environments.
# ---------------------------------------------------------------------------------------------------------------------

SHELL := /bin/bash
TF_DIR := terraform
ENV ?= dev
AWS_REGION ?= me-central-1
AWS_PROFILE ?= default

# ---------------------------------------------------------------------------------------------------------------------
# Colors
# ---------------------------------------------------------------------------------------------------------------------
BLUE := \033[36m
GREEN := \033[32m
YELLOW := \033[33m
RED := \033[31m
NC := \033[0m

# ---------------------------------------------------------------------------------------------------------------------
# Help
# ---------------------------------------------------------------------------------------------------------------------
.PHONY: help
help: ## Show this help message
	@echo -e "$(BLUE)Saudi Bank Backend - Infrastructure Makefile$(NC)"
	@echo ""
	@echo "Usage: make <target> ENV=<dev|staging|prod>"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(GREEN)%-25s$(NC) %s\n", $$1, $$2}'

# ---------------------------------------------------------------------------------------------------------------------
# Pre-Flight & Bootstrap
# ---------------------------------------------------------------------------------------------------------------------
.PHONY: preflight
preflight: ## Run pre-flight checks (AWS creds, versions, quotas)
	@echo -e "$(BLUE)Running pre-flight checks...$(NC)"
	@bash scripts/pre-flight-checks.sh

.PHONY: bootstrap
bootstrap: ## Bootstrap S3 + DynamoDB backend for the selected ENV
	@echo -e "$(BLUE)Bootstrapping backend for environment: $(ENV)$(NC)"
	@TF_STATE_BUCKET=$$(grep 'bucket_name' terraform/environments/$(ENV)/terraform.tfvars | head -1 | sed 's/.*= *"\(.*\)".*/\1/') && \
	 TF_LOCK_TABLE=$$(grep 'dynamodb_table_name' terraform/environments/$(ENV)/terraform.tfvars | head -1 | sed 's/.*= *"\(.*\)".*/\1/') && \
	 ENVIRONMENT=$(ENV) bash scripts/bootstrap-backend.sh

# ---------------------------------------------------------------------------------------------------------------------
# Terraform Commands
# ---------------------------------------------------------------------------------------------------------------------
.PHONY: init
init: ## Initialize Terraform for the selected ENV
	@echo -e "$(BLUE)Initializing Terraform for $(ENV)...$(NC)"
	cd $(TF_DIR) && terraform init \
	  -backend-config="environments/$(ENV)/backend.hcl" 2>/dev/null || \
	terraform init \
	  -backend-config="bucket=$$(grep 'bucket_name' environments/$(ENV)/terraform.tfvars | head -1 | sed 's/.*= *"\(.*\)".*/\1/')" \
	  -backend-config="key=terraform/$(ENV)/terraform.tfstate" \
	  -backend-config="region=$(AWS_REGION)" \
	  -backend-config="dynamodb_table=$$(grep 'dynamodb_table_name' environments/$(ENV)/terraform.tfvars | head -1 | sed 's/.*= *"\(.*\)".*/\1/')" \
	  -backend-config="encrypt=true"

.PHONY: validate
validate: ## Run terraform validate
	@echo -e "$(BLUE)Validating Terraform...$(NC)"
	cd $(TF_DIR) && terraform validate

.PHONY: plan
plan: ## Run terraform plan for the selected ENV
	@echo -e "$(BLUE)Planning for $(ENV)...$(NC)"
	cd $(TF_DIR) && terraform plan -var-file="environments/$(ENV)/terraform.tfvars"

.PHONY: apply
apply: ## Run terraform apply for the selected ENV (with confirmation)
	@echo -e "$(YELLOW)WARNING: You are about to apply changes to $(ENV).$(NC)"
	@read -p "Are you sure? [y/N] " confirm && [[ $$confirm == [yY] ]] || exit 1
	cd $(TF_DIR) && terraform apply -var-file="environments/$(ENV)/terraform.tfvars"

.PHONY: apply-auto
apply-auto: ## Run terraform apply for the selected ENV (auto-approve)
	@echo -e "$(YELLOW)Auto-applying to $(ENV)...$(NC)"
	cd $(TF_DIR) && terraform apply -auto-approve -var-file="environments/$(ENV)/terraform.tfvars"

.PHONY: destroy
destroy: ## Run terraform destroy for the selected ENV (with confirmation)
	@echo -e "$(RED)WARNING: You are about to DESTROY $(ENV).$(NC)"
	@read -p "Are you absolutely sure? Type 'destroy' to confirm: " confirm && [[ $$confirm == "destroy" ]] || exit 1
	cd $(TF_DIR) && terraform destroy -var-file="environments/$(ENV)/terraform.tfvars"

.PHONY: fmt
fmt: ## Run terraform fmt
	@echo -e "$(BLUE)Formatting Terraform code...$(NC)"
	cd $(TF_DIR) && terraform fmt -recursive

.PHONY: lint
lint: ## Run tflint
	@echo -e "$(BLUE)Running tflint...$(NC)"
	cd $(TF_DIR) && tflint --recursive

# ---------------------------------------------------------------------------------------------------------------------
# Security Scanning
# ---------------------------------------------------------------------------------------------------------------------
.PHONY: checkov
checkov: ## Run Checkov on Terraform code
	@echo -e "$(BLUE)Running Checkov...$(NC)"
	checkov -d $(TF_DIR) --framework terraform

.PHONY: tfsec
tfsec: ## Run tfsec on Terraform code
	@echo -e "$(Blue)Running tfsec...$(NC)"
	tfsec $(TF_DIR)

# ---------------------------------------------------------------------------------------------------------------------
# Kubernetes & GitOps
# ---------------------------------------------------------------------------------------------------------------------
.PHONY: kubeconfig
kubeconfig: ## Update kubeconfig for the EKS cluster in the selected ENV
	@echo -e "$(BLUE)Updating kubeconfig for $(ENV)...$(NC)"
	aws eks update-kubeconfig --region $(AWS_REGION) --name saudi-bank-backend-$(ENV)-eks --profile $(AWS_PROFILE)

.PHONY: argocd-login
argocd-login: ## Port-forward to ArgoCD and retrieve initial password
	@echo -e "$(BLUE)Setting up ArgoCD port-forward...$(NC)"
	@kubectl port-forward svc/argocd-server -n argocd 8080:443 &
	@echo -e "$(GREEN)ArgoCD UI: https://localhost:8080$(NC)"
	@echo -e "$(YELLOW)Initial admin password:$(NC)"
	@kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath="{.data.password}" | base64 -d && echo

.PHONY: argocd-sync-dev
argocd-sync-dev: ## Sync ArgoCD dev application
	kubectl patch application dev-apps -n argocd --type merge -p '{"operation": {"sync": {"syncStrategy": {"hook": {}}}}}'

.PHONY: argocd-sync-staging
argocd-sync-staging: ## Sync ArgoCD staging application
	kubectl patch application staging-apps -n argocd --type merge -p '{"operation": {"sync": {"syncStrategy": {"hook": {}}}}}'

.PHONY: argocd-sync-prod
argocd-sync-prod: ## Sync ArgoCD prod application
	kubectl patch application prod-apps -n argocd --type merge -p '{"operation": {"sync": {"syncStrategy": {"hook": {}}}}}'

# ---------------------------------------------------------------------------------------------------------------------
# Lock File Management
# ---------------------------------------------------------------------------------------------------------------------
.PHONY: lock
lock: ## Generate or update .terraform.lock.hcl
	@echo -e "$(BLUE)Generating Terraform lock file...$(NC)"
	cd $(TF_DIR) && terraform providers lock \
	  -platform=linux_amd64 \
	  -platform=linux_arm64 \
	  -platform=darwin_amd64 \
	  -platform=darwin_arm64 \
	  -platform=windows_amd64

# ---------------------------------------------------------------------------------------------------------------------
# All-in-One
# ---------------------------------------------------------------------------------------------------------------------
.PHONY: infra
infra: preflight init validate ## Deploy AWS infrastructure only (VPC, EKS, RDS, etc.)
	@echo -e "$(BLUE)Deploying AWS infrastructure for $(ENV)...$(NC)"
	cd $(TF_DIR) && terraform apply -auto-approve \
	  -var-file="environments/$(ENV)/terraform.tfvars" \
	  -target=module.networking \
	  -target=module.security \
	  -target=module.compliance \
	  -target=module.database \
	  -target=module.eks

.PHONY: k8s
k8s: kubeconfig ## Deploy Kubernetes addons (ArgoCD, Prometheus, Grafana) after cluster is ready
	@echo -e "$(BLUE)Deploying Kubernetes addons for $(ENV)...$(NC)"
	cd $(TF_DIR) && terraform apply -auto-approve \
	  -var-file="environments/$(ENV)/terraform.tfvars" \
	  -target=module.observability \
	  -target=module.gitops

.PHONY: deploy-dev
deploy-dev: infra k8s argocd-sync-dev ## Full deploy pipeline for dev (two-phase)

.PHONY: deploy-staging
deploy-staging: infra k8s argocd-sync-staging ## Full deploy pipeline for staging (two-phase)

.PHONY: deploy-prod
deploy-prod: infra k8s argocd-sync-prod ## Full deploy pipeline for prod (two-phase, manual confirm on apply)
