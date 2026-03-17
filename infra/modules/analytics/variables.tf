variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment (dev, staging, prod)"
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
