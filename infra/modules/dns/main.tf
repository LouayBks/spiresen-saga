# Route 53 hosted zone for the root domain, plus a wildcard ACM cert covering the
# apex and every subdomain off it. The cert must live in us-east-1 regardless of the
# zone's own region — that's a hard CloudFront requirement — so it's created via the
# aws.us_east_1 provider alias the caller passes in.

resource "aws_route53_zone" "root" {
  name = var.domain_name
  tags = var.tags
}

resource "aws_acm_certificate" "wildcard" {
  provider = aws.us_east_1

  domain_name               = var.domain_name
  subject_alternative_names = ["*.${var.domain_name}"]
  validation_method         = "DNS"
  tags                      = var.tags

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "cert_validation" {
  # Keyed by resource_record_name, not domain_name: the apex and its "*.<apex>" SAN can
  # resolve to the identical validation CNAME (ACM deduplicates them). "..." groups any
  # duplicate keys into a list instead of erroring, and only the first is kept.
  for_each = {
    for name, dvos in {
      for dvo in aws_acm_certificate.wildcard.domain_validation_options : dvo.resource_record_name => dvo...
      } : name => {
      name   = dvos[0].resource_record_name
      record = dvos[0].resource_record_value
      type   = dvos[0].resource_record_type
    }
  }

  zone_id = aws_route53_zone.root.zone_id
  name    = each.value.name
  type    = each.value.type
  records = [each.value.record]
  ttl     = 60
}

resource "aws_acm_certificate_validation" "wildcard" {
  provider = aws.us_east_1

  certificate_arn         = aws_acm_certificate.wildcard.arn
  validation_record_fqdns = [for r in aws_route53_record.cert_validation : r.fqdn]
}
