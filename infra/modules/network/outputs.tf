output "vpc_id" {
  description = "Id of the VPC."
  value       = aws_vpc.this.id
}

output "private_subnet_ids" {
  description = "Private subnets the Lambda runs in."
  value       = aws_subnet.private[*].id
}

output "lambda_security_group_id" {
  description = "Security group attached to the Lambda."
  value       = aws_security_group.lambda.id
}
