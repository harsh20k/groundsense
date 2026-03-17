output "glue_database_name" {
  description = "Name of the Glue catalog database"
  value       = aws_glue_catalog_database.seismic_data.name
}

output "glue_crawler_name" {
  description = "Name of the Glue crawler"
  value       = aws_glue_crawler.seismic_data.name
}

output "athena_workgroup_name" {
  description = "Name of the Athena workgroup"
  value       = aws_athena_workgroup.seismic_analysis.name
}

output "athena_results_bucket_name" {
  description = "Name of the Athena results S3 bucket"
  value       = aws_s3_bucket.athena_results.bucket
}
