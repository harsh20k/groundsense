output "knowledge_base_id" {
  description = "ID of the Bedrock Knowledge Base"
  value       = module.knowledge_base.knowledge_base_id
}

output "data_source_id" {
  description = "ID of the Bedrock Data Source"
  value       = module.knowledge_base.data_source_id
}

output "vector_bucket_name" {
  description = "Name of the S3 Vectors bucket"
  value       = module.knowledge_base.vector_bucket_name
}

output "vector_index_name" {
  description = "Name of the S3 Vector index"
  value       = module.knowledge_base.vector_index_name
}

output "knowledge_base_arn" {
  description = "ARN of the Bedrock Knowledge Base"
  value       = module.knowledge_base.knowledge_base_arn
}
