terraform {
  required_version = ">= 1.9"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  # Same state bucket as prod (from infra/bootstrap), different key — see
  # environments/prod/versions.tf for why this literal can't be a variable.
  backend "s3" {
    bucket       = "spiresen-saga-tfstate"
    key          = "environments/int/terraform.tfstate"
    region       = "eu-west-3"
    use_lockfile = true
    encrypt      = true
  }
}
