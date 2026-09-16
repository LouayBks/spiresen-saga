provider "aws" {
  region = var.aws_region

  default_tags {
    tags = local.tags
  }
}

provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"

  default_tags {
    tags = local.tags
  }
}

locals {
  tags = {
    Project     = "spiresen-saga"
    Environment = "prod"
    ManagedBy   = "terraform"
  }
}

module "dns" {
  source = "../../modules/dns"

  domain_name = var.domain_name
  tags        = local.tags

  providers = {
    aws           = aws
    aws.us_east_1 = aws.us_east_1
  }
}
