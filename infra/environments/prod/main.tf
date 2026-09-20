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

module "static_site" {
  source = "../../modules/static-site"

  bucket_name     = var.static_site_bucket_name
  domain_name     = var.app_domain_name
  certificate_arn = module.dns.certificate_arn # *.spiresen.com wildcard already covers a one-label subdomain
  route53_zone_id = module.dns.zone_id
  tags            = local.tags
}

module "api" {
  source = "../../modules/api"

  function_name   = var.api_function_name
  lambda_zip_path = var.lambda_zip_path
  tags            = local.tags
}
