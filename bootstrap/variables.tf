variable "aws_region" {
  description = "Region for the shared bootstrap resources."
  type        = string
  default     = "eu-central-1"
}

variable "project" {
  description = "Project name, used as a prefix for shared resource names."
  type        = string
  default     = "health-check"
}

variable "github_owner" {
  description = "GitHub account that owns the repository allowed to deploy."
  type        = string
  default     = "0xarkade"
}

variable "github_repo" {
  description = "Repository allowed to assume the deploy roles."
  type        = string
  default     = "serverless-health-check-api"
}

variable "environments" {
  description = "Environments that get their own deploy role."
  type        = list(string)
  default     = ["staging", "prod"]
}
