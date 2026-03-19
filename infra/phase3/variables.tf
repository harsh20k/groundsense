variable "project_name" {
  description = "Project name"
  type        = string
  default     = "groundsense"
}

variable "environment" {
  description = "Environment (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

# Phase 1 outputs (from Phase 1 terraform state)
variable "dynamodb_table_name" {
  description = "DynamoDB table name for recent earthquakes"
  type        = string
}

variable "athena_workgroup_name" {
  description = "Athena workgroup name"
  type        = string
}

variable "glue_database_name" {
  description = "Glue database name"
  type        = string
}

variable "s3_athena_output_bucket" {
  description = "S3 bucket for Athena query results"
  type        = string
}

# Phase 2 outputs (from Phase 2 terraform state)
variable "knowledge_base_id" {
  description = "Bedrock Knowledge Base ID"
  type        = string
}
