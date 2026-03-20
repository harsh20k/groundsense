output "api_invoke_url" {
  description = "POST JSON {query, session_id?} to this URL (path includes /invoke)"
  value       = "${aws_api_gateway_stage.main.invoke_url}/invoke"
}

output "formatter_lambda_name" {
  description = "Lambda function name (from data source)"
  value       = data.aws_lambda_function.formatter.function_name
}

output "frontend_bucket_id" {
  description = "S3 bucket for static build artifacts (aws s3 sync dist/ s3://...)"
  value       = aws_s3_bucket.frontend.id
}

output "cloudfront_domain_name" {
  description = "CloudFront hostname for the SPA (set VITE_API_URL to api_invoke_url when building)"
  value       = aws_cloudfront_distribution.frontend.domain_name
}

output "cloudfront_distribution_id" {
  description = "Use for cache invalidation after deploy"
  value       = aws_cloudfront_distribution.frontend.id
}
