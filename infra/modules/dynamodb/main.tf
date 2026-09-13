resource "aws_dynamodb_table" "this" {
  name = var.name

  # On demand billing. Health check traffic is unpredictable and low, so there
  # is no capacity to plan and nothing to pay when the endpoint is idle.
  billing_mode = "PAY_PER_REQUEST"

  hash_key = "id"

  attribute {
    name = "id"
    type = "S"
  }

  # DynamoDB is always encrypted, so this does not switch encryption on. It
  # replaces the AWS owned key with a customer managed one, which is what puts
  # key policy, rotation and revocation under our control.
  server_side_encryption {
    enabled     = true
    kms_key_arn = var.kms_key_arn
  }
}
