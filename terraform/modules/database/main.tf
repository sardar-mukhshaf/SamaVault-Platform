# ---------------------------------------------------------------------------------------------------------------------
# Database Module
# RDS PostgreSQL 15+ Multi-AZ with KMS encryption, Secrets Manager auto-rotation.
# ---------------------------------------------------------------------------------------------------------------------

locals {
  db_identifier = "${var.name_prefix}-postgres"
}

# ---------------------------------------------------------------------------------------------------------------------
# RDS Subnet Group
# ---------------------------------------------------------------------------------------------------------------------

# The subnet group is created in the networking module to avoid cyclic dependencies.
# We reference it via var.database_subnet_group_name.

# ---------------------------------------------------------------------------------------------------------------------
# DB Parameter Group
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_db_parameter_group" "main" {
  name   = "${local.db_identifier}-params"
  family = "postgres15"

  parameter {
    name  = "log_connections"
    value = "1"
  }

  parameter {
    name  = "log_disconnections"
    value = "1"
  }

  parameter {
    name  = "log_checkpoints"
    value = "1"
  }

  parameter {
    name  = "log_min_duration_statement"
    value = "1000"
  }

  tags = merge(var.common_tags, {
    Name = "${local.db_identifier}-params"
  })
}

# ---------------------------------------------------------------------------------------------------------------------
# Security Group for RDS
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_security_group" "database" {
  name_prefix = "${local.db_identifier}-sg-"
  vpc_id      = var.vpc_id
  description = "Security group for RDS PostgreSQL"

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
    description = "PostgreSQL access from VPC CIDR"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.common_tags, {
    Name = "${local.db_identifier}-sg"
  })
}

# ---------------------------------------------------------------------------------------------------------------------
# Secrets Manager Secret for DB Credentials
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_secretsmanager_secret" "db_credentials" {
  name                    = "${local.db_identifier}-credentials"
  description             = "Credentials for ${local.db_identifier}"
  kms_key_id              = var.kms_key_id
  recovery_window_in_days = var.environment == "prod" ? 30 : 7

  tags = merge(var.common_tags, {
    Name = "${local.db_identifier}-credentials"
  })
}

resource "aws_secretsmanager_secret_version" "db_credentials" {
  secret_id = aws_secretsmanager_secret.db_credentials.id
  secret_string = jsonencode({
    username = var.db_username
    password = random_password.db_master.result
    dbname   = var.db_name
    host     = aws_db_instance.main.address
    port     = aws_db_instance.main.port
  })

  depends_on = [aws_db_instance.main]
}

resource "random_password" "db_master" {
  length           = 32
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# ---------------------------------------------------------------------------------------------------------------------
# Secrets Manager Auto-Rotation
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_secretsmanager_secret_rotation" "db_credentials" {
  secret_id           = aws_secretsmanager_secret.db_credentials.id
  rotation_lambda_arn = aws_lambda_function.rotation.arn

  rotation_rules {
    automatically_after_days = 30
  }
}

resource "aws_lambda_function" "rotation" {
  function_name = "${local.db_identifier}-rotation"
  role          = aws_iam_role.rotation_lambda.arn
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.11"
  timeout       = 30

  # Placeholder for rotation lambda package
  filename         = data.archive_file.rotation_lambda_dummy.output_path
  source_code_hash = data.archive_file.rotation_lambda_dummy.output_base64sha256

  vpc_config {
    subnet_ids         = var.database_subnet_ids
    security_group_ids = [aws_security_group.database.id]
  }

  environment {
    variables = {
      SECRETS_MANAGER_ENDPOINT = "https://secretsmanager.${var.primary_region}.amazonaws.com"
    }
  }

  tags = merge(var.common_tags, {
    Name = "${local.db_identifier}-rotation"
  })
}

resource "aws_iam_role" "rotation_lambda" {
  name = "${local.db_identifier}-rotation-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(var.common_tags, {
    Name = "${local.db_identifier}-rotation-role"
  })
}

resource "aws_iam_role_policy_attachment" "rotation_lambda_vpc" {
  role       = aws_iam_role.rotation_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_role_policy" "rotation_lambda" {
  name = "${local.db_identifier}-rotation-policy"
  role = aws_iam_role.rotation_lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:DescribeSecret",
          "secretsmanager:GetSecretValue",
          "secretsmanager:PutSecretValue",
          "secretsmanager:UpdateSecretVersionStage"
        ]
        Resource = aws_secretsmanager_secret.db_credentials.arn
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:log-group:/aws/lambda/${local.db_identifier}-rotation:*"
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateNetworkInterface",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DeleteNetworkInterface"
        ]
        Resource = "*"
      }
    ]
  })
}

# Dummy archive for lambda placeholder
data "archive_file" "rotation_lambda_dummy" {
  type        = "zip"
  output_path = "${path.module}/rotation_lambda.zip"

  source {
    content  = <<EOF
import json

def lambda_handler(event, context):
    # This is a placeholder. In production, use AWS Secrets Manager rotation lambda templates.
    print(json.dumps(event))
    return {"statusCode": 200, "body": "Rotation placeholder"}
EOF
    filename = "lambda_function.py"
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# RDS Instance
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_db_instance" "main" {
  identifier     = local.db_identifier
  engine         = "postgres"
  engine_version = "15.4"
  instance_class = var.db_instance_class

  db_name  = var.db_name
  username = var.db_username
  password = random_password.db_master.result

  multi_az               = var.multi_az
  storage_encrypted      = var.storage_encrypted
  kms_key_id             = var.kms_key_id
  allocated_storage      = 100
  max_allocated_storage  = 1000
  storage_type           = "gp3"

  db_subnet_group_name   = var.database_subnet_group_name
  vpc_security_group_ids = [aws_security_group.database.id]
  parameter_group_name   = aws_db_parameter_group.main.name

  backup_retention_period = var.backup_retention
  backup_window           = "03:00-04:00"
  maintenance_window      = "Mon:04:00-Mon:05:00"

  performance_insights_enabled    = var.enable_performance_insights
  performance_insights_kms_key_id = var.enable_performance_insights ? var.kms_key_id : null

  deletion_protection = var.deletion_protection
  skip_final_snapshot = var.skip_final_snapshot

  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]

  tags = merge(var.common_tags, {
    Name = local.db_identifier
  })

  lifecycle {
    prevent_destroy = true
  }
}
