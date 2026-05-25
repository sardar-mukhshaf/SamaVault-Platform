#!/usr/bin/env bash
# ---------------------------------------------------------------------------------------------------------------------
# Bootstrap Backend Script
# Safely creates S3 bucket + DynamoDB table for Terraform remote state.
# Idempotent: safe to run multiple times.
# ---------------------------------------------------------------------------------------------------------------------

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# ---------------------------------------------------------------------------------------------------------------------
# Configuration (override via environment variables)
# ---------------------------------------------------------------------------------------------------------------------
BUCKET_NAME="${TF_STATE_BUCKET:-}"
DYNAMO_TABLE="${TF_LOCK_TABLE:-}"
REGION="${AWS_REGION:-me-central-1}"
PROFILE="${AWS_PROFILE:-default}"
ENVIRONMENT="${ENVIRONMENT:-dev}"

if [[ -z "$BUCKET_NAME" || -z "$DYNAMO_TABLE" ]]; then
  echo -e "${RED}ERROR: TF_STATE_BUCKET and TF_LOCK_TABLE must be set.${NC}"
  echo "Usage: TF_STATE_BUCKET=my-bucket TF_LOCK_TABLE=my-table ENVIRONMENT=dev ./scripts/bootstrap-backend.sh"
  exit 1
fi

# ---------------------------------------------------------------------------------------------------------------------
# Helper Functions
# ---------------------------------------------------------------------------------------------------------------------

log_info() {
  echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
  echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
  echo -e "${RED}[ERROR]${NC} $1"
}

aws_cmd() {
  aws --region "$REGION" --profile "$PROFILE" "$@"
}

# ---------------------------------------------------------------------------------------------------------------------
# Pre-Flight Checks
# ---------------------------------------------------------------------------------------------------------------------

log_info "Checking AWS credentials..."
if ! aws_cmd sts get-caller-identity &>/dev/null; then
  log_error "AWS credentials not configured or invalid."
  exit 1
fi

ACCOUNT_ID=$(aws_cmd sts get-caller-identity --query Account --output text)
log_info "Authenticated to AWS Account: $ACCOUNT_ID"

# ---------------------------------------------------------------------------------------------------------------------
# S3 Bucket Creation (Idempotent)
# ---------------------------------------------------------------------------------------------------------------------

log_info "Ensuring S3 bucket '$BUCKET_NAME' exists..."

if aws_cmd s3api head-bucket --bucket "$BUCKET_NAME" 2>/dev/null; then
  log_warn "Bucket '$BUCKET_NAME' already exists. Skipping creation."
else
  # Some regions require LocationConstraint, others do not (e.g., us-east-1)
  if [[ "$REGION" == "us-east-1" ]]; then
    aws_cmd s3api create-bucket --bucket "$BUCKET_NAME"
  else
    aws_cmd s3api create-bucket \
      --bucket "$BUCKET_NAME" \
      --create-bucket-configuration LocationConstraint="$REGION"
  fi
  log_info "Bucket '$BUCKET_NAME' created."
fi

log_info "Applying S3 bucket security settings..."

# Enable versioning
aws_cmd s3api put-bucket-versioning \
  --bucket "$BUCKET_NAME" \
  --versioning-configuration Status=Enabled

# Enable default encryption (AES256 for bootstrap, can upgrade to KMS later)
aws_cmd s3api put-bucket-encryption \
  --bucket "$BUCKET_NAME" \
  --server-side-encryption-configuration '{
    "Rules": [
      {
        "ApplyServerSideEncryptionByDefault": {
          "SSEAlgorithm": "AES256"
        },
        "BucketKeyEnabled": true
      }
    ]
  }'

# Block all public access
aws_cmd s3api put-public-access-block \
  --bucket "$BUCKET_NAME" \
  --public-access-block-configuration \
  "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"

# Enforce SSL/TLS only
aws_cmd s3api put-bucket-policy \
  --bucket "$BUCKET_NAME" \
  --policy "{
    \"Version\": \"2012-10-17\",
    \"Statement\": [
      {
        \"Sid\": \"EnforceTLS\",
        \"Effect\": \"Deny\",
        \"Principal\": \"*\",
        \"Action\": \"s3:*\",
        \"Resource\": [
          \"arn:aws:s3:::${BUCKET_NAME}\",
          \"arn:aws:s3:::${BUCKET_NAME}/*\"
        ],
        \"Condition\": {
          \"Bool\": {
            \"aws:SecureTransport\": \"false\"
          }
        }
      }
    ]
  }"

# Enable access logging (logs to itself under /logs prefix)
aws_cmd s3api put-bucket-logging \
  --bucket "$BUCKET_NAME" \
  --bucket-logging-status "{
    \"LoggingEnabled\": {
      \"TargetBucket\": \"${BUCKET_NAME}\",
      \"TargetPrefix\": \"logs/\"
    }
  }" 2>/dev/null || log_warn "Could not enable access logging (may require separate bucket)."

# MFA Delete requires root MFA; skip in automation, note in docs
log_warn "MFA Delete must be enabled manually via root account for production."

log_info "S3 bucket '$BUCKET_NAME' configured successfully."

# ---------------------------------------------------------------------------------------------------------------------
# DynamoDB Table Creation (Idempotent)
# ---------------------------------------------------------------------------------------------------------------------

log_info "Ensuring DynamoDB table '$DYNAMO_TABLE' exists..."

if aws_cmd dynamodb describe-table --table-name "$DYNAMO_TABLE" &>/dev/null; then
  log_warn "DynamoDB table '$DYNAMO_TABLE' already exists. Skipping creation."
else
  aws_cmd dynamodb create-table \
    --table-name "$DYNAMO_TABLE" \
    --attribute-definitions AttributeName=LockID,AttributeType=S \
    --key-schema AttributeName=LockID,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST

  # Wait for table to be active
  log_info "Waiting for DynamoDB table to become ACTIVE..."
  aws_cmd dynamodb wait table-exists --table-name "$DYNAMO_TABLE"
  log_info "DynamoDB table '$DYNAMO_TABLE' created."
fi

# Enable point-in-time recovery for the lock table (best practice)
aws_cmd dynamodb update-continuous-backups \
  --table-name "$DYNAMO_TABLE" \
  --point-in-time-recovery-specification PointInTimeRecoveryEnabled=true 2>/dev/null || \
  log_warn "Could not enable point-in-time recovery for lock table."

# ---------------------------------------------------------------------------------------------------------------------
# Output Backend Configuration
# ---------------------------------------------------------------------------------------------------------------------

cat <<EOF

${GREEN}===============================================================${NC}
${GREEN}  Terraform Backend Bootstrap Complete${NC}
${GREEN}===============================================================${NC}

S3 Bucket:        $BUCKET_NAME
DynamoDB Table:   $DYNAMO_TABLE
Region:           $REGION
Environment:      $ENVIRONMENT
Account ID:       $ACCOUNT_ID

Backend config for terraform init:

  terraform init \\
    -backend-config="bucket=$BUCKET_NAME" \\
    -backend-config="key=terraform/$ENVIRONMENT/terraform.tfstate" \\
    -backend-config="region=$REGION" \\
    -backend-config="dynamodb_table=$DYNAMO_TABLE" \\
    -backend-config="encrypt=true"

Or create a backend.hcl file:

  bucket         = "$BUCKET_NAME"
  key            = "terraform/$ENVIRONMENT/terraform.tfstate"
  region         = "$REGION"
  dynamodb_table = "$DYNAMO_TABLE"
  encrypt        = true

Then run:

  terraform init -backend-config=backend.hcl

${YELLOW}REMINDER:${NC}
  - Enable MFA Delete on the S3 bucket manually via root account.
  - Rotate bootstrap credentials and use IAM roles / OIDC for CI/CD.
  - Consider cross-region replication for the state bucket in production.

${GREEN}===============================================================${NC}
EOF
