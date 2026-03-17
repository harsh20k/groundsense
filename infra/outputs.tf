output "dynamodb_table_name" {
  description = "Name of the DynamoDB earthquakes table"
  value       = module.storage.dynamodb_table_name
}

output "seismic_archive_bucket_name" {
  description = "Name of the seismic archive S3 bucket"
  value       = module.storage.seismic_archive_bucket_name
}

output "documents_bucket_name" {
  description = "Name of the documents S3 bucket"
  value       = module.storage.documents_bucket_name
}

output "seismic_poller_function_name" {
  description = "Name of the seismic poller Lambda function"
  value       = module.ingestors.seismic_poller_function_name
}

output "document_fetcher_function_name" {
  description = "Name of the document fetcher Lambda function"
  value       = module.ingestors.document_fetcher_function_name
}

output "alert_lambda_function_name" {
  description = "Name of the alert Lambda function"
  value       = module.triggers.alert_lambda_function_name
}

output "kb_sync_lambda_function_name" {
  description = "Name of the KB sync Lambda function"
  value       = module.triggers.kb_sync_lambda_function_name
}

output "sns_topic_arn" {
  description = "ARN of the SNS alerts topic"
  value       = module.triggers.sns_topic_arn
}

output "glue_database_name" {
  description = "Name of the Glue catalog database"
  value       = module.analytics.glue_database_name
}

output "athena_workgroup_name" {
  description = "Name of the Athena workgroup"
  value       = module.analytics.athena_workgroup_name
}
