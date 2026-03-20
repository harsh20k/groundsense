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

variable "formatter_lambda_name" {
  description = "Name of the Phase 4 response-formatter Lambda (terraform output formatter_function_name from infra/phase4)"
  type        = string
}

variable "api_stage_name" {
  description = "API Gateway deployment stage name"
  type        = string
  default     = "dev"
}
