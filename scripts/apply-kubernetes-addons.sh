#!/usr/bin/env bash
# ---------------------------------------------------------------------------------------------------------------------
# Apply Kubernetes Addons
# After the EKS cluster is created, this script updates kubeconfig and applies
# the observability and gitops modules (Helm releases, ArgoCD apps, etc.).
# ---------------------------------------------------------------------------------------------------------------------

set -euo pipefail

ENVIRONMENT="${ENVIRONMENT:-dev}"
AWS_REGION="${AWS_REGION:-me-central-1}"
CLUSTER_NAME="saudi-bank-backend-${ENVIRONMENT}-eks"

if [[ "$ENVIRONMENT" == "prod" ]]; then
  CLUSTER_NAME="saudi-bank-backend-prod-eks"
fi

echo "[INFO] Updating kubeconfig for cluster: $CLUSTER_NAME"
aws eks update-kubeconfig --region "$AWS_REGION" --name "$CLUSTER_NAME"

echo "[INFO] Verifying cluster connectivity..."
kubectl cluster-info

echo "[INFO] Applying Kubernetes addons via Terraform..."
cd terraform

# Run terraform apply targeting only the K8s-dependent modules
# These modules use the kubernetes and helm providers.
terraform apply \
  -var-file="environments/${ENVIRONMENT}/terraform.tfvars" \
  -target=module.observability \
  -target=module.gitops

echo "[INFO] Kubernetes addons applied successfully."
