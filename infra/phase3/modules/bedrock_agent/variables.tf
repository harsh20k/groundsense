variable "project_name" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment (dev, staging, prod)"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "get_recent_earthquakes_lambda_arn" {
  description = "ARN of get_recent_earthquakes Lambda function"
  type        = string
}

variable "analyze_historical_patterns_lambda_arn" {
  description = "ARN of analyze_historical_patterns Lambda function"
  type        = string
}

variable "get_hazard_assessment_lambda_arn" {
  description = "ARN of get_hazard_assessment Lambda function"
  type        = string
}

variable "get_location_context_lambda_arn" {
  description = "ARN of get_location_context Lambda function"
  type        = string
}

variable "fetch_weather_at_epicenter_lambda_arn" {
  description = "ARN of fetch_weather_at_epicenter Lambda function"
  type        = string
}

variable "knowledge_base_id" {
  description = "Bedrock Knowledge Base ID"
  type        = string
}

variable "bedrock_model_id" {
  description = "Bedrock foundation model or inference profile ID. Swap without code changes. Claude 3.5+ needs us.* inference profile; Gemma is NOT supported (no tool-calling)."
  type        = string
  default     = "us.amazon.nova-pro-v1:0"
}
