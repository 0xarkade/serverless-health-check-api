variable "name" {
  description = "Name of the REST API."
  type        = string
}

variable "stage_name" {
  description = "Stage name, which is also the environment name."
  type        = string
}

variable "lambda_invoke_arn" {
  description = "Invoke ARN of the function behind the endpoint."
  type        = string
}

variable "lambda_function_name" {
  description = "Name of that function, used to grant invoke permission."
  type        = string
}

variable "throttle_rate_limit" {
  description = "Steady state requests per second."
  type        = number
}

variable "throttle_burst_limit" {
  description = "Burst capacity above the steady rate."
  type        = number
}
