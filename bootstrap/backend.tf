terraform {
  # Backend blocks cannot use variables or locals, so these are literals.
  backend "s3" {
    bucket       = "health-check-tfstate-701364614525"
    key          = "bootstrap/terraform.tfstate"
    region       = "eu-central-1"
    use_lockfile = true
  }
}
