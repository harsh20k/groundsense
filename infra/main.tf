# Triggers module (must be created before storage for S3 event notifications)
module "triggers" {
  source = "./modules/triggers"

  project_name              = var.project_name
  environment               = var.environment
  seismic_archive_bucket_arn = "arn:aws:s3:::${var.project_name}-${var.environment}-seismic-archive"
  documents_bucket_arn      = "arn:aws:s3:::${var.project_name}-${var.environment}-documents"
  alert_email               = var.alert_email
  knowledge_base_id         = var.knowledge_base_id
  data_source_id            = var.data_source_id
}

# Storage module
module "storage" {
  source = "./modules/storage"

  project_name   = var.project_name
  environment    = var.environment
  
  alert_lambda_arn           = module.triggers.alert_lambda_arn
  kb_sync_lambda_arn         = module.triggers.kb_sync_lambda_arn
  alert_lambda_permission    = module.triggers.alert_lambda_permission
  kb_sync_lambda_permission  = module.triggers.kb_sync_lambda_permission
}

# Ingestors module
module "ingestors" {
  source = "./modules/ingestors"

  project_name                 = var.project_name
  environment                  = var.environment
  dynamodb_table_name          = module.storage.dynamodb_table_name
  dynamodb_table_arn           = module.storage.dynamodb_table_arn
  seismic_archive_bucket_name  = module.storage.seismic_archive_bucket_name
  seismic_archive_bucket_arn   = module.storage.seismic_archive_bucket_arn
  documents_bucket_name        = module.storage.documents_bucket_name
  documents_bucket_arn         = module.storage.documents_bucket_arn
  dynamodb_ttl_days            = var.dynamodb_ttl_days
}

# IAM permissions module
module "iam" {
  source = "./modules/iam"

  project_name  = var.project_name
  environment   = var.environment
  aws_region    = var.aws_region
}

# Analytics module
module "analytics" {
  source = "./modules/analytics"

  project_name                = var.project_name
  environment                 = var.environment
  seismic_archive_bucket_name = module.storage.seismic_archive_bucket_name
  seismic_archive_bucket_arn  = module.storage.seismic_archive_bucket_arn
}
