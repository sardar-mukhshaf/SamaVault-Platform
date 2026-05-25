# ---------------------------------------------------------------------------------------------------------------------
# Networking Module Outputs
# ---------------------------------------------------------------------------------------------------------------------

output "vpc_id" {
  description = "The ID of the VPC."
  value       = aws_vpc.main.id
}

output "vpc_cidr_block" {
  description = "The CIDR block of the VPC."
  value       = aws_vpc.main.cidr_block
}

output "public_subnet_ids" {
  description = "List of public subnet IDs."
  value       = values(aws_subnet.public)[*].id
}

output "private_subnet_ids" {
  description = "List of private subnet IDs."
  value       = values(aws_subnet.private)[*].id
}

output "database_subnet_ids" {
  description = "List of database subnet IDs."
  value       = values(aws_subnet.database)[*].id
}

output "database_subnet_group_name" {
  description = "Name of the database subnet group."
  value       = aws_db_subnet_group.main.name
}

output "nat_gateway_ids" {
  description = "List of NAT Gateway IDs."
  value       = values(aws_nat_gateway.main)[*].id
}

output "internet_gateway_id" {
  description = "The ID of the Internet Gateway."
  value       = aws_internet_gateway.main.id
}

output "transit_gateway_id" {
  description = "The ID of the Transit Gateway (if enabled)."
  value       = var.enable_transit_gateway ? aws_ec2_transit_gateway.main[0].id : null
}

output "route53_health_check_id" {
  description = "The ID of the Route53 health check."
  value       = aws_route53_health_check.primary.id
}


