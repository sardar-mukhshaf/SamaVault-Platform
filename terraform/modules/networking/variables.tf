# ---------------------------------------------------------------------------------------------------------------------
# Networking Module Variables
# ---------------------------------------------------------------------------------------------------------------------

variable "project_name" {
  description = "Name of the project."
  type        = string
}

variable "environment" {
  description = "Deployment environment."
  type        = string
}

variable "common_tags" {
  description = "Common tags for all resources."
  type        = map(string)
  default     = {}
}

variable "name_prefix" {
  description = "Computed name prefix for resources."
  type        = string
}

variable "primary_region" {
  description = "Primary AWS region."
  type        = string
}

variable "secondary_region" {
  description = "Secondary AWS region."
  type        = string
}

variable "cidr_blocks" {
  description = "Map of CIDR blocks for VPC and subnet tiers."
  type        = map(string)

  validation {
    condition     = alltrue([for cidr in values(var.cidr_blocks) : can(cidrhost(cidr, 0))])
    error_message = "All CIDR blocks must be valid IPv4 CIDR notation."
  }
}

variable "availability_zones" {
  description = "List of availability zones to use."
  type        = list(string)
}

variable "enable_transit_gateway" {
  description = "Whether to create a Transit Gateway for cross-region connectivity."
  type        = bool
  default     = false
}

variable "peer_region_vpc_id" {
  description = "VPC ID in the peer region for peering."
  type        = string
  default     = null
}

variable "nat_gateway_per_az" {
  description = "Create one NAT Gateway per AZ for HA."
  type        = bool
  default     = true
}

variable "enable_vpc_flow_logs" {
  description = "Enable VPC Flow Logs."
  type        = bool
  default     = true
}

variable "flow_logs_retention_days" {
  description = "Retention period for flow logs in S3 (days). Default ~7 years."
  type        = number
  default     = 2555
}
