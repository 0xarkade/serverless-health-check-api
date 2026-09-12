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
