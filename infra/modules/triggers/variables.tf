variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment (dev, staging, prod)"
  type        = string
}

variable "seismic_archive_bucket_arn" {
  description = "ARN of the seismic archive S3 bucket"
  type        = string
}

variable "documents_bucket_arn" {
  description = "ARN of the documents S3 bucket"
  type        = string
}

variable "alert_email" {
  description = "Email address for SNS alert subscription"
  type        = string
  default     = ""
}

variable "knowledge_base_id" {
  description = "Bedrock Knowledge Base ID (from Phase 2)"
  type        = string
  default     = ""
}

variable "data_source_id" {
  description = "Bedrock Data Source ID (from Phase 2)"
  type        = string
  default     = ""
}
