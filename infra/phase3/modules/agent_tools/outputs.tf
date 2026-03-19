output "get_recent_earthquakes_function_arn" {
  description = "ARN of get_recent_earthquakes Lambda function"
  value       = aws_lambda_function.get_recent_earthquakes.arn
}

output "get_recent_earthquakes_function_name" {
  description = "Name of get_recent_earthquakes Lambda function"
  value       = aws_lambda_function.get_recent_earthquakes.function_name
}

output "analyze_historical_patterns_function_arn" {
  description = "ARN of analyze_historical_patterns Lambda function"
  value       = aws_lambda_function.analyze_historical_patterns.arn
}

output "analyze_historical_patterns_function_name" {
  description = "Name of analyze_historical_patterns Lambda function"
  value       = aws_lambda_function.analyze_historical_patterns.function_name
}

output "get_hazard_assessment_function_arn" {
  description = "ARN of get_hazard_assessment Lambda function"
  value       = aws_lambda_function.get_hazard_assessment.arn
}

output "get_hazard_assessment_function_name" {
  description = "Name of get_hazard_assessment Lambda function"
  value       = aws_lambda_function.get_hazard_assessment.function_name
}
