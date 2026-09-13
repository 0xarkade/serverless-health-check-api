module "kms" {
  source = "./modules/kms"

  name                    = "${var.environment}-health-check-key"
  description             = "Encrypts the ${var.environment} health check data at rest."
  deletion_window_in_days = var.kms_deletion_window_days
}

module "dynamodb" {
  source = "./modules/dynamodb"

  name        = "${var.environment}-requests-db"
  kms_key_arn = module.kms.key_arn
}

module "network" {
  source = "./modules/network"

  name_prefix = var.environment
  cidr_block  = var.vpc_cidr
  region      = var.aws_region
}
