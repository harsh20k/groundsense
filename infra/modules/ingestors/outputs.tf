output "seismic_poller_function_name" {
  description = "Name of the seismic poller Lambda function"
  value       = aws_lambda_function.seismic_poller.function_name
}

output "seismic_poller_function_arn" {
  description = "ARN of the seismic poller Lambda function"
  value       = aws_lambda_function.seismic_poller.arn
}

output "document_fetcher_function_name" {
  description = "Name of the document fetcher Lambda function"
  value       = aws_lambda_function.document_fetcher.function_name
}

output "document_fetcher_function_arn" {
  description = "ARN of the document fetcher Lambda function"
  value       = aws_lambda_function.document_fetcher.arn
}
