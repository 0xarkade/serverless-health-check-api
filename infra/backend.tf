terraform {
  # Partial configuration. Bucket, key and region are supplied at init time
  # from environments/<env>.backend.hcl so that one root module serves both
  # environments with separate state files.
  backend "s3" {}
}
