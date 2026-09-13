variable "name" {
  description = "Name for the key alias, without the alias/ prefix."
  type        = string
}

variable "description" {
  description = "What the key is used for."
  type        = string
}

variable "deletion_window_in_days" {
  description = "Days the key stays recoverable after deletion is scheduled."
  type        = number
  default     = 30
}
