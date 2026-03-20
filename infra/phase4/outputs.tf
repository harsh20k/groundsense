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
