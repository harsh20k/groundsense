module "knowledge_base" {
  source = "./modules/knowledge_base"

  project_name         = var.project_name
  environment          = var.environment
  aws_region           = var.aws_region
  documents_bucket_arn = var.documents_bucket_arn
}
