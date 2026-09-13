data "aws_iam_policy_document" "deploy_assume_role" {
  for_each = toset(var.environments)

  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    # Binds each role to one GitHub Environment. The prod role can only be
    # assumed by a job running in the prod environment, so its approval gate
    # is enforced by IAM rather than by the workflow file alone.
    #
    # Two subjects are listed because GitHub now issues the immutable form,
    # which pins the account and repository by numeric id so that renaming or
    # recreating either one invalidates the trust. The classic form is kept so
    # the policy does not depend on which format GitHub emits. Both are exact
    # matches, so neither widens what can assume the role.
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values = [
        "repo:${var.github_owner}/${var.github_repo}:environment:${each.value}",
        "repo:${var.github_owner}@${var.github_owner_id}/${var.github_repo}@${var.github_repo_id}:environment:${each.value}",
      ]
    }
  }
}

resource "aws_iam_role" "deploy" {
  for_each = toset(var.environments)

  name               = "${each.value}-deploy-role"
  description        = "Assumed by GitHub Actions to deploy the ${each.value} environment."
  assume_role_policy = data.aws_iam_policy_document.deploy_assume_role[each.value].json
}
