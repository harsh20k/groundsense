output "agent_id" {
  description = "Bedrock Agent ID"
  value       = aws_bedrockagent_agent.main.agent_id
}

output "agent_arn" {
  description = "Bedrock Agent ARN"
  value       = aws_bedrockagent_agent.main.agent_arn
}

output "agent_alias_id" {
  description = "Bedrock Agent Alias ID"
  value       = aws_bedrockagent_agent_alias.main.agent_alias_id
}

output "agent_alias_arn" {
  description = "Bedrock Agent Alias ARN"
  value       = aws_bedrockagent_agent_alias.main.agent_alias_arn
}

output "guardrail_id" {
  description = "Bedrock Guardrail ID"
  value       = aws_bedrock_guardrail.earthquake_safety.guardrail_id
}

output "guardrail_version" {
  description = "Bedrock Guardrail Version"
  value       = aws_bedrock_guardrail.earthquake_safety.version
}
