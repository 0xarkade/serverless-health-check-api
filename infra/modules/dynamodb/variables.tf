variable "name" {
  description = "Name of the table."
  type        = string
}

variable "kms_key_arn" {
  description = "Customer managed key used to encrypt the table."
  type        = string
}
