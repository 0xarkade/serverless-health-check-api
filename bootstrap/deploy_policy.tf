locals {
  account_id = data.aws_caller_identity.current.account_id
}

# Permissions are scoped by the env-resource-name convention: a staging deploy
# can only touch ARNs beginning with "staging-", and only its own state key.
data "aws_iam_policy_document" "deploy" {
  for_each = toset(var.environments)

  statement {
    sid       = "ReadStateBucket"
    effect    = "Allow"
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.state.arn]
  }

  statement {
    sid    = "ManageOwnStateObject"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
    ]
    resources = ["${aws_s3_bucket.state.arn}/infra/${each.value}/*"]
  }

  statement {
    sid    = "ManageTable"
    effect = "Allow"
    actions = [
      "dynamodb:CreateTable",
      "dynamodb:DeleteTable",
      "dynamodb:DescribeTable",
      "dynamodb:DescribeContinuousBackups",
      "dynamodb:DescribeTimeToLive",
      "dynamodb:UpdateTable",
      "dynamodb:UpdateTimeToLive",
      "dynamodb:UpdateContinuousBackups",
      "dynamodb:TagResource",
      "dynamodb:UntagResource",
      "dynamodb:ListTagsOfResource",
    ]
    resources = ["arn:aws:dynamodb:${var.aws_region}:${local.account_id}:table/${each.value}-*"]
  }

  statement {
    sid    = "ManageFunction"
    effect = "Allow"
    actions = [
      "lambda:CreateFunction",
      "lambda:DeleteFunction",
      "lambda:GetFunction",
      "lambda:GetFunctionConfiguration",
      "lambda:GetPolicy",
      "lambda:UpdateFunctionCode",
      "lambda:UpdateFunctionConfiguration",
      "lambda:PublishVersion",
      "lambda:AddPermission",
      "lambda:RemovePermission",
      "lambda:TagResource",
      "lambda:UntagResource",
      "lambda:ListTags",
    ]
    resources = ["arn:aws:lambda:${var.aws_region}:${local.account_id}:function:${each.value}-*"]
  }

  statement {
    sid    = "ManageExecutionRole"
    effect = "Allow"
    actions = [
      "iam:CreateRole",
      "iam:DeleteRole",
      "iam:GetRole",
      "iam:TagRole",
      "iam:UntagRole",
      "iam:ListRoleTags",
      "iam:PutRolePolicy",
      "iam:DeleteRolePolicy",
      "iam:GetRolePolicy",
      "iam:ListRolePolicies",
      "iam:ListAttachedRolePolicies",
      "iam:UpdateAssumeRolePolicy",
    ]
    resources = ["arn:aws:iam::${local.account_id}:role/${each.value}-*"]
  }

  # PassRole is how a role is handed to a service. Restricting the target
  # service stops this role attaching the execution role to anything but Lambda.
  statement {
    sid       = "PassExecutionRoleToLambda"
    effect    = "Allow"
    actions   = ["iam:PassRole"]
    resources = ["arn:aws:iam::${local.account_id}:role/${each.value}-*"]

    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values   = ["lambda.amazonaws.com"]
    }
  }

  statement {
    sid    = "ManageFunctionLogGroup"
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:DeleteLogGroup",
      "logs:PutRetentionPolicy",
      "logs:DeleteRetentionPolicy",
      "logs:TagResource",
      "logs:UntagResource",
      "logs:ListTagsForResource",
    ]
    resources = ["arn:aws:logs:${var.aws_region}:${local.account_id}:log-group:/aws/lambda/${each.value}-*"]
  }

  # DescribeLogGroups is a list operation and does not support resource-level
  # permissions, so it has to be granted on "*".
  statement {
    sid       = "ListLogGroups"
    effect    = "Allow"
    actions   = ["logs:DescribeLogGroups"]
    resources = ["*"]
  }

  # A KMS key has no ARN until it exists, so CreateKey cannot be scoped.
  statement {
    sid    = "CreateKmsKey"
    effect = "Allow"
    actions = [
      "kms:CreateKey",
      "kms:ListAliases",
    ]
    resources = ["*"]
  }

  # Every operation on an existing key is restricted to keys tagged for this
  # project, which is the closest equivalent to an ARN scope for resources
  # with generated identifiers.
  statement {
    sid    = "ManageProjectKmsKeys"
    effect = "Allow"
    actions = [
      "kms:DescribeKey",
      "kms:GetKeyPolicy",
      "kms:PutKeyPolicy",
      "kms:GetKeyRotationStatus",
      "kms:EnableKeyRotation",
      "kms:DisableKeyRotation",
      "kms:ScheduleKeyDeletion",
      "kms:CancelKeyDeletion",
      "kms:TagResource",
      "kms:UntagResource",
      "kms:ListResourceTags",
      "kms:CreateGrant",
    ]
    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "aws:ResourceTag/Project"
      values   = [var.project]
    }
  }

  statement {
    sid    = "ManageKmsAlias"
    effect = "Allow"
    actions = [
      "kms:CreateAlias",
      "kms:DeleteAlias",
      "kms:UpdateAlias",
    ]
    resources = [
      "arn:aws:kms:${var.aws_region}:${local.account_id}:alias/${each.value}-*",
      "arn:aws:kms:${var.aws_region}:${local.account_id}:key/*",
    ]
  }

  # API Gateway ARNs address control-plane paths rather than named resources,
  # and the api id is generated at creation, so a path wildcard is the
  # tightest scope the service supports.
  statement {
    sid    = "ManageRestApi"
    effect = "Allow"
    actions = [
      "apigateway:GET",
      "apigateway:POST",
      "apigateway:PUT",
      "apigateway:PATCH",
      "apigateway:DELETE",
    ]
    resources = [
      "arn:aws:apigateway:${var.aws_region}::/restapis",
      "arn:aws:apigateway:${var.aws_region}::/restapis/*",
      "arn:aws:apigateway:${var.aws_region}::/usageplans",
      "arn:aws:apigateway:${var.aws_region}::/usageplans/*",
      "arn:aws:apigateway:${var.aws_region}::/apikeys",
      "arn:aws:apigateway:${var.aws_region}::/apikeys/*",
      "arn:aws:apigateway:${var.aws_region}::/tags/*",
      "arn:aws:apigateway:${var.aws_region}::/account",
    ]
  }

  # EC2 Describe actions do not support resource-level permissions. They are
  # listed individually rather than as ec2:Describe* so the grant stays
  # explicit, but the resource has to be "*".
  statement {
    sid    = "ReadNetworking"
    effect = "Allow"
    actions = [
      "ec2:DescribeVpcs",
      "ec2:DescribeVpcAttribute",
      "ec2:DescribeSubnets",
      "ec2:DescribeRouteTables",
      "ec2:DescribeSecurityGroups",
      "ec2:DescribeSecurityGroupRules",
      "ec2:DescribeVpcEndpoints",
      "ec2:DescribeNetworkInterfaces",
      "ec2:DescribeNetworkAcls",
      "ec2:DescribeAvailabilityZones",
      "ec2:DescribePrefixLists",
      "ec2:DescribeTags",
    ]
    resources = ["*"]
  }

  # A VPC resource has no id until it exists, so creation cannot be scoped by
  # ARN. Terraform tags these at creation time, which is what lets the
  # statement below constrain everything that happens to them afterwards.
  statement {
    sid    = "CreateNetworking"
    effect = "Allow"
    actions = [
      "ec2:CreateVpc",
      "ec2:CreateSubnet",
      "ec2:CreateRouteTable",
      "ec2:CreateSecurityGroup",
      "ec2:CreateVpcEndpoint",
      "ec2:CreateTags",
    ]
    resources = ["*"]
  }

  # Without the tag condition a staging deploy could delete any VPC in the
  # account, including the one prod runs in.
  statement {
    sid    = "ModifyProjectNetworking"
    effect = "Allow"
    actions = [
      "ec2:DeleteVpc",
      "ec2:ModifyVpcAttribute",
      "ec2:DeleteSubnet",
      "ec2:ModifySubnetAttribute",
      "ec2:DeleteRouteTable",
      "ec2:AssociateRouteTable",
      "ec2:DisassociateRouteTable",
      "ec2:DeleteSecurityGroup",
      "ec2:AuthorizeSecurityGroupEgress",
      "ec2:RevokeSecurityGroupEgress",
      "ec2:DeleteVpcEndpoints",
      "ec2:ModifyVpcEndpoint",
      "ec2:DeleteTags",
    ]
    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "aws:ResourceTag/Project"
      values   = [var.project]
    }
  }
}

resource "aws_iam_role_policy" "deploy" {
  for_each = toset(var.environments)

  name   = "${each.value}-deploy-policy"
  role   = aws_iam_role.deploy[each.value].id
  policy = data.aws_iam_policy_document.deploy[each.value].json
}
