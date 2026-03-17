variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment (dev, staging, prod)"
  type        = string
}

variable "alert_lambda_arn" {
  description = "ARN of the alert Lambda function for S3 event notification"
  type        = string
}

variable "kb_sync_lambda_arn" {
  description = "ARN of the KB sync Lambda function for S3 event notification"
  type        = string
}

variable "alert_lambda_permission" {
  description = "Alert Lambda permission resource (for depends_on)"
  type        = any
}

variable "kb_sync_lambda_permission" {
  description = "KB sync Lambda permission resource (for depends_on)"
  type        = any
}
