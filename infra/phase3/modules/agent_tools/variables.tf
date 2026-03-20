variable "project_name" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment (dev, staging, prod)"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

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

variable "knowledge_base_id" {
  description = "Bedrock Knowledge Base ID"
  type        = string
}
