output "formatter_function_name" {
  description = "Response formatter Lambda function name"
  value       = aws_lambda_function.response_formatter.function_name
}

output "formatter_function_arn" {
  description = "Response formatter Lambda function ARN"
  value       = aws_lambda_function.response_formatter.arn
}

output "formatter_function_url" {
  description = "Response formatter Lambda function URL"
  value       = aws_lambda_function_url.response_formatter.function_url
}

output "agent_observability_dashboard_name" {
  description = "CloudWatch dashboard for agent + tool Lambda metrics and custom turn metrics"
  value       = aws_cloudwatch_dashboard.agent_observability.dashboard_name
}
