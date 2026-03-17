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

variable "dynamodb_ttl_days" {
  description = "TTL in days for DynamoDB items"
  type        = number
  default     = 30
}

variable "alert_email" {
  description = "Email address for SNS alert subscription"
  type        = string
  default     = "vn328490@dal.ca"
}
