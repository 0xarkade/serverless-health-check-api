# No key policy is set, so AWS applies its default: the account root is
# granted access, which is what allows IAM policies to delegate use of the
# key. DynamoDB obtains its own access through a grant created when the
# encrypted table is built.
resource "aws_kms_key" "this" {
  description             = var.description
  enable_key_rotation     = true
  deletion_window_in_days = var.deletion_window_in_days
}

resource "aws_kms_alias" "this" {
  name          = "alias/${var.name}"
  target_key_id = aws_kms_key.this.key_id
}
