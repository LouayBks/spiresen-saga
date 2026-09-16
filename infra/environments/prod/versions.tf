terraform {
  required_version = ">= 1.9"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  # Backend blocks can't reference variables — this literal must match
  # infra/bootstrap/'s state_bucket_name output. Migrating here from local state
  # requires the human step in DOC/architecture (bootstrap applied once, then
  # `terraform init -migrate-state` run by hand) before this takes effect.
  # use_lockfile: native S3 state locking (Terraform >= 1.10) — no DynamoDB table.
  backend "s3" {
    bucket       = "spiresen-saga-tfstate"
    key          = "environments/prod/terraform.tfstate"
    region       = "eu-west-3"
    use_lockfile = true
    encrypt      = true
  }
}
