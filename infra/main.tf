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

module "lambda" {
  source = "./modules/lambda"

  function_name      = "${var.environment}-health-check-function"
  source_dir         = "${path.root}/../src/health_check"
  environment        = var.environment
  memory_size        = var.lambda_memory_size
  timeout            = var.lambda_timeout
  log_retention_days = var.log_retention_days
  table_name         = module.dynamodb.table_name
  table_arn          = module.dynamodb.table_arn
  kms_key_arn        = module.kms.key_arn
  region             = var.aws_region
  subnet_ids         = module.network.private_subnet_ids
  security_group_ids = [module.network.lambda_security_group_id]
}

module "api_gateway" {
  source = "./modules/api_gateway"

  name                 = "${var.environment}-health-check-api"
  stage_name           = var.environment
  lambda_invoke_arn    = module.lambda.invoke_arn
  lambda_function_name = module.lambda.function_name
  throttle_rate_limit  = var.api_throttle_rate_limit
  throttle_burst_limit = var.api_throttle_burst_limit
}
