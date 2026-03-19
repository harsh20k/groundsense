output "knowledge_base_id" {
  description = "ID of the Bedrock Knowledge Base"
  value       = aws_bedrockagent_knowledge_base.main.id
}

output "knowledge_base_arn" {
  description = "ARN of the Bedrock Knowledge Base"
  value       = aws_bedrockagent_knowledge_base.main.arn
}

output "data_source_id" {
  description = "ID of the Bedrock Data Source"
  value       = aws_bedrockagent_data_source.documents.data_source_id
}

output "vector_bucket_name" {
  description = "Name of the S3 Vectors bucket"
  value       = aws_s3vectors_vector_bucket.embeddings.vector_bucket_name
}

output "vector_index_name" {
  description = "Name of the S3 Vector index"
  value       = aws_s3vectors_index.documents.index_name
}

output "bedrock_kb_role_arn" {
  description = "ARN of the Bedrock Knowledge Base IAM role"
  value       = aws_iam_role.bedrock_kb.arn
}
