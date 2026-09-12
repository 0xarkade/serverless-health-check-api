output "state_bucket_name" {
  description = "S3 bucket holding Terraform state for all stacks."
  value       = aws_s3_bucket.state.id
}

output "account_id" {
  description = "AWS account the bootstrap stack was applied to."
  value       = data.aws_caller_identity.current.account_id
}
