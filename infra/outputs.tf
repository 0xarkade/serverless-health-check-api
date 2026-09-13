output "health_url" {
  description = "URL of the deployed health endpoint."
  value       = module.api_gateway.health_url
}

output "api_key_value" {
  description = "Api key callers must send as the x-api-key header."
  value       = module.api_gateway.api_key_value
  sensitive   = true
}

output "table_name" {
  description = "DynamoDB table requests are written to."
  value       = module.dynamodb.table_name
}

output "function_name" {
  description = "Name of the health check function."
  value       = module.lambda.function_name
}
