variable "function_name" {
  description = "Name of the function."
  type        = string
}

variable "source_dir" {
  description = "Directory zipped into the deployment package."
  type        = string
}

variable "handler" {
  description = "Module and function the runtime calls."
  type        = string
  default     = "app.lambda_handler"
}

variable "runtime" {
  description = "Lambda runtime."
  type        = string
  default     = "python3.13"
}

variable "memory_size" {
  description = "Memory in MB."
  type        = number
}

variable "timeout" {
  description = "Timeout in seconds."
  type        = number
}

variable "environment" {
  description = "Environment name, passed to the function as ENVIRONMENT."
  type        = string
}

variable "table_name" {
  description = "DynamoDB table the function writes to."
  type        = string
}

variable "table_arn" {
  description = "ARN of that table, used to scope the write permission."
  type        = string
}

variable "log_retention_days" {
  description = "How long CloudWatch keeps the function logs."
  type        = number
}

variable "subnet_ids" {
  description = "Private subnets the function runs in."
  type        = list(string)
}

variable "security_group_ids" {
  description = "Security groups attached to the function."
  type        = list(string)
}

variable "kms_key_arn" {
  description = "Key the table is encrypted with. The function needs to use it to write."
  type        = string
}

variable "region" {
  description = "Region, used to pin KMS use to the DynamoDB service."
  type        = string
}
