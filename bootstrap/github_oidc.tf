# Lets GitHub Actions exchange a short-lived workflow token for AWS credentials,
# so no access keys are stored as repository secrets. AWS validates the issuer
# against its own trust store, so no thumbprint is required.
resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
}
