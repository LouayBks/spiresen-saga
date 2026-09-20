output "zone_id" {
  description = "Route 53 hosted zone ID — set as the NS delegation target at the registrar."
  value       = aws_route53_zone.root.zone_id
}

output "name_servers" {
  description = "NS records to set at the registrar (Namecheap) to delegate the domain to this zone."
  value       = aws_route53_zone.root.name_servers
}

output "certificate_arn" {
  description = "ARN of the validated wildcard ACM cert, for use by CloudFront distributions."
  value       = aws_acm_certificate_validation.wildcard.certificate_arn
}
