variable "aws_region" {
  description = "AWS region for resource deployment"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "groundsense"
}

variable "environment" {
  description = "Environment (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "documents_bucket_name" {
  description = "Name of the documents S3 bucket from Phase 1"
  type        = string
}

variable "documents_bucket_arn" {
  description = "ARN of the documents S3 bucket from Phase 1"
  type        = string
}
