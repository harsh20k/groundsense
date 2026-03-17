output "project_owner_user_name" {
  description = "Name of the project-owner IAM user"
  value       = aws_iam_user.project_owner.name
}

output "project_owner_user_arn" {
  description = "ARN of the project-owner IAM user"
  value       = aws_iam_user.project_owner.arn
}

output "project_owner_policy_arn" {
  description = "ARN of the project-owner IAM policy"
  value       = aws_iam_policy.project_owner.arn
}

output "project_owner_policy_name" {
  description = "Name of the project-owner IAM policy"
  value       = aws_iam_policy.project_owner.name
}
