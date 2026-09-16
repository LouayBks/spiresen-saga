terraform {
  required_version = ">= 1.9"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  # Deliberately local state — this config creates the remote-state backend that
  # infra/environments/* migrate to, so it can't depend on that backend existing yet.
  # Applied once, by hand, per DOC/architecture/branching_strategy.md's AW-24.
}

provider "aws" {
  region = var.aws_region
}
