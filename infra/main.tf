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
