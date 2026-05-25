#!/usr/bin/env bash
# ---------------------------------------------------------------------------------------------------------------------
# Pre-Flight Checks Script
# Validates AWS credentials, required IAM permissions, and service quotas.
# Exit code 0 = all checks passed. Non-zero = at least one failure.
# ---------------------------------------------------------------------------------------------------------------------

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# ---------------------------------------------------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------------------------------------------------
REGION="${AWS_REGION:-me-central-1}"
PROFILE="${AWS_PROFILE:-default}"
REQUIRED_QUOTAS=(
  "L-1194D1C8:5"    # VPCs per Region (minimum 5)
  "L-3819A6DF:3"    # EKS clusters per Region (minimum 3)
  "L-FE5A3802:5"    # NAT Gateways per AZ (minimum 5)
)

PASS=0
FAIL=0

# ---------------------------------------------------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------------------------------------------------

log_pass() { echo -e "${GREEN}[PASS]${NC} $1"; ((PASS++)) || true; }
log_fail() { echo -e "${RED}[FAIL]${NC} $1"; ((FAIL++)) || true; }
log_info() { echo -e "${YELLOW}[INFO]${NC} $1"; }

aws_cmd() {
  aws --region "$REGION" --profile "$PROFILE" "$@" 2>/dev/null
}

# ---------------------------------------------------------------------------------------------------------------------
# Check 1: AWS CLI Version
# ---------------------------------------------------------------------------------------------------------------------

echo ""
echo "=== AWS CLI Version Check ==="
AWS_CLI_VERSION=$(aws --version 2>/dev/null | awk '{print $1}' | cut -d/ -f2 || echo "")
if [[ -z "$AWS_CLI_VERSION" ]]; then
  log_fail "AWS CLI is not installed or not in PATH."
else
  log_pass "AWS CLI version: $AWS_CLI_VERSION"
fi

# ---------------------------------------------------------------------------------------------------------------------
# Check 2: AWS Credentials
# ---------------------------------------------------------------------------------------------------------------------

echo ""
echo "=== AWS Credentials Check ==="
if aws_cmd sts get-caller-identity &>/dev/null; then
  ACCOUNT_ID=$(aws_cmd sts get-caller-identity --query Account --output text)
  CALLER_ARN=$(aws_cmd sts get-caller-identity --query Arn --output text)
  log_pass "AWS credentials valid. Account: $ACCOUNT_ID, Caller: $CALLER_ARN"
else
  log_fail "AWS credentials are missing or invalid. Run 'aws configure' or set env vars."
fi

# ---------------------------------------------------------------------------------------------------------------------
# Check 3: Region Accessibility
# ---------------------------------------------------------------------------------------------------------------------

echo ""
echo "=== Region Accessibility Check ==="
if aws_cmd ec2 describe-availability-zones --query 'AvailabilityZones[0].ZoneName' --output text &>/dev/null; then
  AZ_COUNT=$(aws_cmd ec2 describe-availability-zones --query 'length(AvailabilityZones)' --output text)
  log_pass "Region '$REGION' is accessible with $AZ_COUNT availability zones."
else
  log_fail "Cannot access region '$REGION'. Check your AWS account has access to this region."
fi

# ---------------------------------------------------------------------------------------------------------------------
# Check 4: Required IAM Permissions (Simulated)
# ---------------------------------------------------------------------------------------------------------------------

echo ""
echo "=== Required IAM Permissions Check ==="

REQUIRED_ACTIONS=(
  "ec2:DescribeVpcs"
  "ec2:CreateVpc"
  "ec2:DescribeSubnets"
  "ec2:CreateSubnet"
  "ec2:DescribeRouteTables"
  "ec2:CreateRouteTable"
  "ec2:DescribeInternetGateways"
  "ec2:CreateInternetGateway"
  "ec2:DescribeNatGateways"
  "ec2:CreateNatGateway"
  "eks:DescribeCluster"
  "eks:CreateCluster"
  "iam:CreateRole"
  "iam:AttachRolePolicy"
  "kms:CreateKey"
  "s3:CreateBucket"
  "dynamodb:CreateTable"
  "rds:CreateDBInstance"
  "logs:CreateLogGroup"
  "cloudtrail:CreateTrail"
)

# Use simulate-principal-policy if we have the caller ARN
if [[ -n "${CALLER_ARN:-}" ]]; then
  SIM_RESULT=$(aws_cmd iam simulate-principal-policy \
    --policy-source-arn "$CALLER_ARN" \
    --action-names "${REQUIRED_ACTIONS[@]}" \
    --resource-arns "arn:aws:ec2:${REGION}:${ACCOUNT_ID}:vpc/*" \
    --query 'EvaluationResults[?EvalDecision!=`allowed`].ActionName' \
    --output text 2>/dev/null || true)

  if [[ -z "$SIM_RESULT" || "$SIM_RESULT" == "None" ]]; then
    log_pass "All required IAM actions are allowed for the current principal."
  else
    log_warn "Some actions may be denied (Simulated): $SIM_RESULT"
    log_warn "If you are using a restricted role, ensure the following are allowed:"
    printf '%s\n' "${REQUIRED_ACTIONS[@]}"
  fi
else
  log_warn "Cannot simulate IAM policy without caller identity. Skipping detailed permission check."
fi

# ---------------------------------------------------------------------------------------------------------------------
# Check 5: Service Quotas
# ---------------------------------------------------------------------------------------------------------------------

echo ""
echo "=== Service Quotas Check ==="

for quota in "${REQUIRED_QUOTAS[@]}"; do
  IFS=':' read -r quota_code min_required <<< "$quota"
  CURRENT_VALUE=$(aws_cmd service-quotas get-service-quota \
    --service-code ec2 \
    --quota-code "$quota_code" \
    --query 'Quota.Value' --output text 2>/dev/null || echo "unknown")

  if [[ "$CURRENT_VALUE" == "unknown" ]]; then
    log_warn "Could not retrieve quota $quota_code. Ensure 'service-quotas:GetServiceQuota' is allowed."
  elif (( $(echo "$CURRENT_VALUE >= $min_required" | bc -l) )); then
    log_pass "Quota $quota_code: $CURRENT_VALUE (required: $min_required)"
  else
    log_fail "Quota $quota_code: $CURRENT_VALUE (required: $min_required). Request increase via AWS Support."
  fi
done

# ---------------------------------------------------------------------------------------------------------------------
# Check 6: Terraform Version
# ---------------------------------------------------------------------------------------------------------------------

echo ""
echo "=== Terraform Version Check ==="
TF_VERSION=$(terraform version -json 2>/dev/null | jq -r '.terraform_version' || echo "")
if [[ -z "$TF_VERSION" ]]; then
  log_fail "Terraform is not installed or not in PATH."
else
  log_pass "Terraform version: $TF_VERSION"
fi

# ---------------------------------------------------------------------------------------------------------------------
# Check 7: kubectl Version
# ---------------------------------------------------------------------------------------------------------------------

echo ""
echo "=== kubectl Version Check ==="
KUBECTL_VERSION=$(kubectl version --client=true -o json 2>/dev/null | jq -r '.clientVersion.gitVersion' || echo "")
if [[ -z "$KUBECTL_VERSION" ]]; then
  log_warn "kubectl is not installed. Required for EKS management."
else
  log_pass "kubectl version: $KUBECTL_VERSION"
fi

# ---------------------------------------------------------------------------------------------------------------------
# Check 8: Helm Version
# ---------------------------------------------------------------------------------------------------------------------

echo ""
echo "=== Helm Version Check ==="
HELM_VERSION=$(helm version --short 2>/dev/null || echo "")
if [[ -z "$HELM_VERSION" ]]; then
  log_warn "Helm is not installed. Required for Kubernetes package management."
else
  log_pass "Helm version: $HELM_VERSION"
fi

# ---------------------------------------------------------------------------------------------------------------------
# Check 9: jq Version
# ---------------------------------------------------------------------------------------------------------------------

echo ""
echo "=== jq Version Check ==="
JQ_VERSION=$(jq --version 2>/dev/null || echo "")
if [[ -z "$JQ_VERSION" ]]; then
  log_warn "jq is not installed. Required for JSON parsing in scripts."
else
  log_pass "jq version: $JQ_VERSION"
fi

# ---------------------------------------------------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------------------------------------------------

echo ""
echo "=========================================="
echo -e "Pre-Flight Summary: ${GREEN}$PASS passed${NC}, ${RED}$FAIL failed${NC}"
echo "=========================================="

if [[ $FAIL -gt 0 ]]; then
  echo -e "${RED}Pre-flight checks FAILED. Resolve issues before proceeding.${NC}"
  exit 1
fi

echo -e "${GREEN}All pre-flight checks passed. Ready to deploy.${NC}"
exit 0
