data "archive_file" "this" {
  type        = "zip"
  source_dir  = var.source_dir
  output_path = "${path.module}/build/${var.function_name}.zip"

  excludes = [
    "__pycache__",
    "*.pyc",
    "*.code-workspace",
  ]
}

# Created here rather than left for Lambda to create on first invocation. That
# keeps logs:CreateLogGroup out of the execution role entirely, and sets a
# retention period instead of the default of keeping logs forever.
resource "aws_cloudwatch_log_group" "this" {
  name              = "/aws/lambda/${var.function_name}"
  retention_in_days = var.log_retention_days
}

data "aws_iam_policy_document" "assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "this" {
  name               = "${var.function_name}-role"
  description        = "Execution role for ${var.function_name}."
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

data "aws_iam_policy_document" "this" {
  statement {
    sid    = "WriteLogs"
    effect = "Allow"
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
    resources = ["${aws_cloudwatch_log_group.this.arn}:*"]
  }

  # The function only ever writes. It has no read, no scan, no delete.
  statement {
    sid       = "WriteRequests"
    effect    = "Allow"
    actions   = ["dynamodb:PutItem"]
    resources = [var.table_arn]
  }

  # A customer managed key means the caller needs its own KMS permissions;
  # the grant DynamoDB holds is not enough. ViaService narrows this to calls
  # DynamoDB makes on the function behalf, so the role cannot use the key for
  # anything else.
  statement {
    sid    = "UseTableKey"
    effect = "Allow"
    actions = [
      "kms:Decrypt",
      "kms:GenerateDataKey",
    ]
    resources = [var.kms_key_arn]

    condition {
      test     = "StringEquals"
      variable = "kms:ViaService"
      values   = ["dynamodb.${var.region}.amazonaws.com"]
    }
  }

  # Lambda attaches and detaches an ENI in the VPC using this role. ENI ids do
  # not exist until creation and DescribeNetworkInterfaces has no resource
  # level permissions, which is why AWS uses * for these three actions in its
  # own VPC access managed policy. Written inline so the grant is visible in
  # code rather than hidden behind a policy ARN.
  statement {
    sid    = "ManageVpcNetworkInterface"
    effect = "Allow"
    actions = [
      "ec2:CreateNetworkInterface",
      "ec2:DescribeNetworkInterfaces",
      "ec2:DeleteNetworkInterface",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "this" {
  name   = "${var.function_name}-policy"
  role   = aws_iam_role.this.id
  policy = data.aws_iam_policy_document.this.json
}

resource "aws_lambda_function" "this" {
  function_name = var.function_name
  role          = aws_iam_role.this.arn
  handler       = var.handler
  runtime       = var.runtime
  memory_size   = var.memory_size
  timeout       = var.timeout

  filename = data.archive_file.this.output_path

  # Redeploys only when the zipped code actually changes.
  source_code_hash = data.archive_file.this.output_base64sha256

  # Each apply publishes an immutable numbered version.
  publish = true

  vpc_config {
    subnet_ids         = var.subnet_ids
    security_group_ids = var.security_group_ids
  }

  environment {
    variables = {
      TABLE_NAME  = var.table_name
      ENVIRONMENT = var.environment
    }
  }

  depends_on = [
    aws_iam_role_policy.this,
    aws_cloudwatch_log_group.this,
  ]
}
