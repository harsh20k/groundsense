variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment (dev, staging, prod)"
  type        = string
}

variable "aws_region" {
  description = "AWS region for resource deployment"
  type        = string
}

variable "documents_bucket_arn" {
  description = "ARN of the documents S3 bucket from Phase 1"
  type        = string
}
