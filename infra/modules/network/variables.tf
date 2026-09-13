variable "name_prefix" {
  description = "Prefix applied to every resource name."
  type        = string
}

variable "cidr_block" {
  description = "CIDR block for the VPC."
  type        = string
}

variable "region" {
  description = "Region, used to build the DynamoDB endpoint service name."
  type        = string
}

variable "subnet_count" {
  description = "Number of private subnets, one per availability zone."
  type        = number
  default     = 2
}
