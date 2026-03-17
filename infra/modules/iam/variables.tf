variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment (dev, staging, prod)"
  type        = string
}

variable "aws_region" {
  description = "AWS region for scoping resource ARNs"
  type        = string
}

variable "iam_user_name" {
  description = "IAM user to attach the project-owner policy to"
  type        = string
  default     = "groundsense-projectowner"
}
