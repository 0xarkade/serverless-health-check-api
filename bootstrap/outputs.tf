output "state_bucket_name" {
  description = "S3 bucket holding Terraform state for all stacks."
  value       = aws_s3_bucket.state.id
}

output "account_id" {
  description = "AWS account the bootstrap stack was applied to."
  value       = data.aws_caller_identity.current.account_id
}

output "deploy_role_arns" {
  description = "Deploy role ARN per environment, used by the GitHub Actions workflow."
  value       = { for env, role in aws_iam_role.deploy : env => role.arn }
}
