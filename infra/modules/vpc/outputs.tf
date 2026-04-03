output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "private_subnet_id" {
  description = "Private subnet ID for Lambda functions"
  value       = aws_subnet.private.id
}

output "lambda_security_group_id" {
  description = "Security group ID for Lambda functions"
  value       = aws_security_group.lambda.id
}

output "s3_endpoint_id" {
  description = "S3 VPC endpoint ID"
  value       = aws_vpc_endpoint.s3.id
}

output "dynamodb_endpoint_id" {
  description = "DynamoDB VPC endpoint ID"
  value       = aws_vpc_endpoint.dynamodb.id
}

output "bedrock_runtime_endpoint_id" {
  description = "Bedrock Runtime VPC endpoint ID"
  value       = aws_vpc_endpoint.bedrock_runtime.id
}

output "bedrock_agent_runtime_endpoint_id" {
  description = "Bedrock Agent Runtime VPC endpoint ID"
  value       = aws_vpc_endpoint.bedrock_agent_runtime.id
}
