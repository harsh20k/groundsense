output "agent_id" {
  description = "Bedrock Agent ID"
  value       = module.bedrock_agent.agent_id
}

output "agent_arn" {
  description = "Bedrock Agent ARN"
  value       = module.bedrock_agent.agent_arn
}

output "agent_alias_id" {
  description = "Bedrock Agent Alias ID (use this to invoke the agent)"
  value       = module.bedrock_agent.agent_alias_id
}

output "agent_alias_arn" {
  description = "Bedrock Agent Alias ARN"
  value       = module.bedrock_agent.agent_alias_arn
}

output "guardrail_id" {
  description = "Bedrock Guardrail ID"
  value       = module.bedrock_agent.guardrail_id
}

output "guardrail_version" {
  description = "Bedrock Guardrail Version"
  value       = module.bedrock_agent.guardrail_version
}

output "get_recent_earthquakes_function_name" {
  description = "Lambda function name for get_recent_earthquakes tool"
  value       = module.agent_tools.get_recent_earthquakes_function_name
}

output "analyze_historical_patterns_function_name" {
  description = "Lambda function name for analyze_historical_patterns tool"
  value       = module.agent_tools.analyze_historical_patterns_function_name
}

output "get_hazard_assessment_function_name" {
  description = "Lambda function name for get_hazard_assessment tool"
  value       = module.agent_tools.get_hazard_assessment_function_name
}
