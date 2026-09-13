output "invoke_url" {
  description = "Base URL of the deployed stage."
  value       = aws_api_gateway_stage.this.invoke_url
}

output "health_url" {
  description = "Full URL of the health endpoint."
  value       = "${aws_api_gateway_stage.this.invoke_url}/health"
}

output "api_key_value" {
  description = "Value of the api key callers must send as x-api-key."
  value       = aws_api_gateway_api_key.this.value
  sensitive   = true
}
