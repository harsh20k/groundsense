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

# Phase 3 outputs (from Phase 3 terraform state)
variable "agent_id" {
  description = "Bedrock Agent ID"
  type        = string
}

variable "agent_alias_id" {
  description = "Bedrock Agent Alias ID"
  type        = string
}

variable "agent_arn" {
  description = "Bedrock Agent ARN"
  type        = string
}

variable "metrics_namespace" {
  description = "CloudWatch custom metric namespace for response_formatter observability"
  type        = string
  default     = "GroundSense"
}
