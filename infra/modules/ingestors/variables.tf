variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment (dev, staging, prod)"
  type        = string
}

variable "dynamodb_table_name" {
  description = "Name of the DynamoDB earthquakes table"
  type        = string
}

variable "dynamodb_table_arn" {
  description = "ARN of the DynamoDB earthquakes table"
  type        = string
}

variable "seismic_archive_bucket_name" {
  description = "Name of the seismic archive S3 bucket"
  type        = string
}

variable "seismic_archive_bucket_arn" {
  description = "ARN of the seismic archive S3 bucket"
  type        = string
}

variable "documents_bucket_name" {
  description = "Name of the documents S3 bucket"
  type        = string
}

variable "documents_bucket_arn" {
  description = "ARN of the documents S3 bucket"
  type        = string
}

variable "dynamodb_ttl_days" {
  description = "TTL in days for DynamoDB items"
  type        = number
}
