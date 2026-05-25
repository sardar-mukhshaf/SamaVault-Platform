# ---------------------------------------------------------------------------------------------------------------------
# Remote State Backend Configuration
# This file configures S3 + DynamoDB for Terraform state management per environment.
# The actual backend is initialized dynamically via the bootstrap script.
# ---------------------------------------------------------------------------------------------------------------------

terraform {
  backend "s3" {
    # These values are intentionally omitted and must be provided via:
    # terraform init -backend-config="bucket=..." -backend-config="key=..." -backend-config="region=..."
    # or via a backend.hcl file per environment.
    encrypt = true
  }
}
