output "dynamodb_table_name" {
  description = "Name of the DynamoDB earthquakes table"
  value       = aws_dynamodb_table.earthquakes.name
}

output "dynamodb_table_arn" {
  description = "ARN of the DynamoDB earthquakes table"
  value       = aws_dynamodb_table.earthquakes.arn
}

output "seismic_archive_bucket_name" {
  description = "Name of the seismic archive S3 bucket"
  value       = aws_s3_bucket.seismic_archive.bucket
}

output "seismic_archive_bucket_arn" {
  description = "ARN of the seismic archive S3 bucket"
  value       = aws_s3_bucket.seismic_archive.arn
}

output "documents_bucket_name" {
  description = "Name of the documents S3 bucket"
  value       = aws_s3_bucket.documents.bucket
}

output "documents_bucket_arn" {
  description = "ARN of the documents S3 bucket"
  value       = aws_s3_bucket.documents.arn
}
