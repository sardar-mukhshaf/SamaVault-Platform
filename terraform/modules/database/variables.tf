# ---------------------------------------------------------------------------------------------------------------------
# Database Module Variables
# ---------------------------------------------------------------------------------------------------------------------

variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "common_tags" {
  type    = map(string)
  default = {}
}

variable "name_prefix" {
  type = string
}

variable "primary_region" {
  type = string
}

variable "db_instance_class" {
  type = string
}

variable "db_name" {
  type = string
}

variable "db_username" {
  type    = string
  default = "dbadmin"
}

variable "backup_retention" {
  type = number
}

variable "enable_performance_insights" {
  type    = bool
  default = true
}

variable "multi_az" {
  type    = bool
  default = true
}

variable "storage_encrypted" {
  type    = bool
  default = true
}

variable "deletion_protection" {
  type    = bool
  default = true
}

variable "skip_final_snapshot" {
  type    = bool
  default = false
}

variable "kms_key_id" {
  type = string
}

variable "database_subnet_group_name" {
  type = string
}

variable "database_subnet_ids" {
  type = list(string)
}

variable "vpc_id" {
  type = string
}

variable "allowed_cidr_blocks" {
  type = list(string)
}
