provider "aws" {
  region = var.aws_region

  default_tags {
    tags = local.tags
  }
}

# CloudFront requires the cert in us-east-1 regardless of this environment's own
# region — same requirement environments/prod's dns module already deals with.
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
    Environment = "dev"
    ManagedBy   = "terraform"
  }
}

# app_domain_name (dev.athar.spiresen.com) is two labels under spiresen.com, so the
# existing *.spiresen.com wildcard cert (environments/prod's module.dns) doesn't
# cover it — request a single-SAN cert for exactly this name, validated in the same
# existing zone (var.route53_zone_id) rather than creating a second hosted zone.
resource "aws_acm_certificate" "app" {
  provider = aws.us_east_1

  domain_name       = var.app_domain_name
  validation_method = "DNS"
  tags              = local.tags

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "app_cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.app.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  zone_id = var.route53_zone_id
  name    = each.value.name
  type    = each.value.type
  records = [each.value.record]
  ttl     = 60
}

resource "aws_acm_certificate_validation" "app" {
  provider = aws.us_east_1

  certificate_arn         = aws_acm_certificate.app.arn
  validation_record_fqdns = [for r in aws_route53_record.app_cert_validation : r.fqdn]
}

module "static_site" {
  source = "../../modules/static-site"

  bucket_name     = var.static_site_bucket_name
  domain_name     = var.app_domain_name
  certificate_arn = aws_acm_certificate_validation.app.certificate_arn
  route53_zone_id = var.route53_zone_id
  tags            = local.tags
}

module "api" {
  source = "../../modules/api"

  function_name   = var.api_function_name
  lambda_zip_path = var.lambda_zip_path
  tags            = local.tags
}
