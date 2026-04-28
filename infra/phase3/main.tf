module "agent_tools" {
  source = "./modules/agent_tools"

  project_name              = var.project_name
  environment               = var.environment
  aws_region                = var.aws_region
  dynamodb_table_name       = var.dynamodb_table_name
  athena_workgroup_name     = var.athena_workgroup_name
  glue_database_name        = var.glue_database_name
  s3_athena_output_bucket   = var.s3_athena_output_bucket
  s3_seismic_archive_bucket = var.s3_seismic_archive_bucket
  knowledge_base_id         = var.knowledge_base_id
  private_subnet_id         = var.private_subnet_id
  lambda_security_group_id  = var.lambda_security_group_id
}

module "bedrock_agent" {
  source = "./modules/bedrock_agent"

  project_name                           = var.project_name
  environment                            = var.environment
  aws_region                             = var.aws_region
  get_recent_earthquakes_lambda_arn      = module.agent_tools.get_recent_earthquakes_function_arn
  analyze_historical_patterns_lambda_arn = module.agent_tools.analyze_historical_patterns_function_arn
  get_hazard_assessment_lambda_arn       = module.agent_tools.get_hazard_assessment_function_arn
  get_location_context_lambda_arn        = module.agent_tools.get_location_context_function_arn
  fetch_weather_at_epicenter_lambda_arn  = module.agent_tools.fetch_weather_at_epicenter_function_arn
  knowledge_base_id                      = var.knowledge_base_id
  bedrock_model_id                       = var.bedrock_model_id
}
