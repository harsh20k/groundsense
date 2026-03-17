output "project_owner_policy_arn" {
  description = "ARN of the project-owner IAM policy"
  value       = aws_iam_policy.project_owner.arn
}

output "project_owner_policy_name" {
  description = "Name of the project-owner IAM policy"
  value       = aws_iam_policy.project_owner.name
}
