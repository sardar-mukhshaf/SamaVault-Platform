# ---------------------------------------------------------------------------------------------------------------------
# Networking Module
# Multi-region VPCs with 3-tier subnets, TGW/peering, Route53 health checks, NAT GW per AZ.
# ---------------------------------------------------------------------------------------------------------------------

locals {
  az_count       = length(var.availability_zones)
  az_suffixes    = [for i, az in var.availability_zones : format("%02d", i + 1)]

  # Subnet CIDR calculations
  public_cidrs    = [for i in range(local.az_count) : cidrsubnet(var.cidr_blocks["vpc"], 4, i)]
  private_cidrs   = [for i in range(local.az_count) : cidrsubnet(var.cidr_blocks["vpc"], 4, i + local.az_count)]
  database_cidrs  = [for i in range(local.az_count) : cidrsubnet(var.cidr_blocks["vpc"], 4, i + (local.az_count * 2))]
}

# ---------------------------------------------------------------------------------------------------------------------
# VPC
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_vpc" "main" {
  cidr_block           = var.cidr_blocks["vpc"]
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-vpc"
  })
}

# ---------------------------------------------------------------------------------------------------------------------
# Internet Gateway
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-igw"
  })
}

# ---------------------------------------------------------------------------------------------------------------------
# Subnets (Public, Private, Database)
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_subnet" "public" {
  for_each = { for idx, az in var.availability_zones : az => {
    cidr = local.public_cidrs[idx]
    suffix = local.az_suffixes[idx]
  }}

  vpc_id                  = aws_vpc.main.id
  cidr_block              = each.value.cidr
  availability_zone       = each.key
  map_public_ip_on_launch = true

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-public-${each.value.suffix}"
    Type = "Public"
  })
}

resource "aws_subnet" "private" {
  for_each = { for idx, az in var.availability_zones : az => {
    cidr = local.private_cidrs[idx]
    suffix = local.az_suffixes[idx]
  }}

  vpc_id            = aws_vpc.main.id
  cidr_block        = each.value.cidr
  availability_zone = each.key

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-private-${each.value.suffix}"
    Type = "Private"
  })
}

resource "aws_subnet" "database" {
  for_each = { for idx, az in var.availability_zones : az => {
    cidr = local.database_cidrs[idx]
    suffix = local.az_suffixes[idx]
  }}

  vpc_id            = aws_vpc.main.id
  cidr_block        = each.value.cidr
  availability_zone = each.key

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-database-${each.value.suffix}"
    Type = "Database"
  })
}

# ---------------------------------------------------------------------------------------------------------------------
# Elastic IPs for NAT Gateways
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_eip" "nat" {
  for_each = var.nat_gateway_per_az ? { for az in var.availability_zones : az => az } : { (var.availability_zones[0]) = var.availability_zones[0] }

  domain = "vpc"

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-nat-eip-${each.key}"
  })

  depends_on = [aws_internet_gateway.main]
}

# ---------------------------------------------------------------------------------------------------------------------
# NAT Gateways
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_nat_gateway" "main" {
  for_each = var.nat_gateway_per_az ? { for az in var.availability_zones : az => az } : { (var.availability_zones[0]) = var.availability_zones[0] }

  allocation_id = aws_eip.nat[each.key].id
  subnet_id     = aws_subnet.public[each.key].id

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-nat-${each.key}"
  })

  depends_on = [aws_internet_gateway.main]
}

# ---------------------------------------------------------------------------------------------------------------------
# Route Tables
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-rt-public"
  })
}

resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.main.id
}

resource "aws_route_table_association" "public" {
  for_each = aws_subnet.public

  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private" {
  for_each = aws_subnet.private

  vpc_id = aws_vpc.main.id

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-rt-private-${each.key}"
  })
}

resource "aws_route" "private_nat" {
  for_each = aws_route_table.private

  route_table_id         = each.value.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.main[each.key].id
}

resource "aws_route_table_association" "private" {
  for_each = aws_subnet.private

  subnet_id      = each.value.id
  route_table_id = aws_route_table.private[each.key].id
}

resource "aws_route_table" "database" {
  vpc_id = aws_vpc.main.id

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-rt-database"
  })
}

# Database subnets are isolated by default (no route to NAT/IGW)
# If you need outbound from DB, add a route to a NAT Gateway.

resource "aws_route_table_association" "database" {
  for_each = aws_subnet.database

  subnet_id      = each.value.id
  route_table_id = aws_route_table.database.id
}

# ---------------------------------------------------------------------------------------------------------------------
# VPC Flow Logs to S3
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_flow_log" "main" {
  count = var.enable_vpc_flow_logs ? 1 : 0

  vpc_id                   = aws_vpc.main.id
  traffic_type             = "ALL"
  log_destination_type     = "s3"
  log_destination          = aws_s3_bucket.flow_logs[0].arn
  max_aggregation_interval = 60

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-flow-log"
  })
}

resource "aws_s3_bucket" "flow_logs" {
  count = var.enable_vpc_flow_logs ? 1 : 0

  bucket = "${var.name_prefix}-flow-logs-${data.aws_caller_identity.current.account_id}"

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-flow-logs"
  })

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_versioning" "flow_logs" {
  count = var.enable_vpc_flow_logs ? 1 : 0

  bucket = aws_s3_bucket.flow_logs[0].id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "flow_logs" {
  count = var.enable_vpc_flow_logs ? 1 : 0

  bucket = aws_s3_bucket.flow_logs[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "flow_logs" {
  count = var.enable_vpc_flow_logs ? 1 : 0

  bucket = aws_s3_bucket.flow_logs[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "flow_logs" {
  count = var.enable_vpc_flow_logs ? 1 : 0

  bucket = aws_s3_bucket.flow_logs[0].id

  rule {
    id     = "archive-old-flow-logs"
    status = "Enabled"

    transition {
      days          = 90
      storage_class = "GLACIER"
    }

    expiration {
      days = var.flow_logs_retention_days
    }
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# Transit Gateway (Optional)
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_ec2_transit_gateway" "main" {
  count = var.enable_transit_gateway ? 1 : 0

  description                     = "${var.name_prefix} Transit Gateway"
  auto_accept_shared_attachments  = "disable"
  default_route_table_association = "enable"
  default_route_table_propagation = "enable"
  dns_support                     = "enable"

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-tgw"
  })
}

resource "aws_ec2_transit_gateway_vpc_attachment" "main" {
  count = var.enable_transit_gateway ? 1 : 0

  subnet_ids         = values(aws_subnet.private)[*].id
  transit_gateway_id = aws_ec2_transit_gateway.main[0].id
  vpc_id             = aws_vpc.main.id

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-tgw-attachment"
  })
}

# ---------------------------------------------------------------------------------------------------------------------
# VPC Peering (Alternative to TGW)
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_vpc_peering_connection" "main" {
  count = var.peer_region_vpc_id != null && !var.enable_transit_gateway ? 1 : 0

  vpc_id        = aws_vpc.main.id
  peer_vpc_id   = var.peer_region_vpc_id
  peer_region   = var.secondary_region
  auto_accept   = false

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-peer"
  })
}

# ---------------------------------------------------------------------------------------------------------------------
# Route53 Health Checks (Failover routing simulation)
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_route53_health_check" "primary" {
  fqdn                    = "health.${var.project_name}.internal"
  port                    = 443
  type                    = "HTTPS"
  resource_path           = "/health"
  failure_threshold       = 3
  request_interval        = 30
  search_string           = "healthy"
  regions                 = ["me-south-1", "ap-southeast-1", "us-east-1"]

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-health-check-primary"
  })
}

# ---------------------------------------------------------------------------------------------------------------------
# DB Subnet Group
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_db_subnet_group" "main" {
  name       = "${var.name_prefix}-db-subnet-group"
  subnet_ids = values(aws_subnet.database)[*].id

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-db-subnet-group"
  })
}

# ---------------------------------------------------------------------------------------------------------------------
# Data Sources
# ---------------------------------------------------------------------------------------------------------------------

data "aws_caller_identity" "current" {}
