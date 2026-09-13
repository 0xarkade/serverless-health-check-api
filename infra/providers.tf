provider "aws" {
  region = var.aws_region

  # The Project tag is not decoration. The deploy role policy allows KMS and
  # VPC operations only on resources carrying it.
  default_tags {
    tags = {
      Project     = var.project
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}
