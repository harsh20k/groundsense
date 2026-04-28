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

variable "s3_seismic_archive_bucket" {
  description = "S3 bucket for seismic data archive"
  type        = string
}

# Phase 2 outputs (from Phase 2 terraform state)
variable "knowledge_base_id" {
  description = "Bedrock Knowledge Base ID"
  type        = string
}

variable "private_subnet_id" {
  description = "Private subnet ID for Lambda VPC configuration"
  type        = string
}

variable "lambda_security_group_id" {
  description = "Security group ID for Lambda functions"
  type        = string
}

variable "bedrock_model_id" {
  description = "Bedrock foundation model or inference profile ID — swap without code changes. See notes/LLM-model-options.md for supported models."
  type        = string
  default     = "us.amazon.nova-pro-v1:0"
}
