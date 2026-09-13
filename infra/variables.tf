variable "environment" {
  description = "Environment name, used as the prefix for every resource."
  type        = string

  validation {
    condition     = contains(["staging", "prod"], var.environment)
    error_message = "The environment must be either staging or prod."
  }
}

variable "aws_region" {
  description = "Region to deploy into."
  type        = string
  default     = "eu-central-1"
}

variable "project" {
  description = "Project tag. Must match the value allowed by the deploy role policy."
  type        = string
  default     = "health-check"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC the Lambda runs in."
  type        = string
}

variable "log_retention_days" {
  description = "How long to keep Lambda logs in CloudWatch."
  type        = number
}

variable "lambda_memory_size" {
  description = "Memory in MB allocated to the Lambda function."
  type        = number
  default     = 256
}

variable "lambda_timeout" {
  description = "Lambda timeout in seconds."
  type        = number
  default     = 10
}

variable "api_throttle_rate_limit" {
  description = "Steady state requests per second allowed by the API stage."
  type        = number
}

variable "api_throttle_burst_limit" {
  description = "Burst capacity allowed by the API stage."
  type        = number
}

variable "kms_deletion_window_days" {
  description = "Days the KMS key stays recoverable after deletion is scheduled."
  type        = number
}
