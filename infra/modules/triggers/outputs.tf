output "alert_lambda_arn" {
  description = "ARN of the alert Lambda function"
  value       = aws_lambda_function.alert.arn
}

output "alert_lambda_function_name" {
  description = "Name of the alert Lambda function"
  value       = aws_lambda_function.alert.function_name
}

output "alert_lambda_permission" {
  description = "Alert Lambda S3 permission resource"
  value       = aws_lambda_permission.alert_s3
}

output "kb_sync_lambda_arn" {
  description = "ARN of the KB sync Lambda function"
  value       = aws_lambda_function.kb_sync.arn
}

output "kb_sync_lambda_function_name" {
  description = "Name of the KB sync Lambda function"
  value       = aws_lambda_function.kb_sync.function_name
}

output "kb_sync_lambda_permission" {
  description = "KB sync Lambda S3 permission resource"
  value       = aws_lambda_permission.kb_sync_s3
}

output "sns_topic_arn" {
  description = "ARN of the SNS alerts topic"
  value       = aws_sns_topic.alerts.arn
}
