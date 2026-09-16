output "dns_zone_id" {
  description = "Route 53 hosted zone ID."
  value       = module.dns.zone_id
}

output "dns_name_servers" {
  description = "NS records to set at Namecheap to delegate spiresen.com to this zone."
  value       = module.dns.name_servers
}

output "wildcard_certificate_arn" {
  description = "ARN of the validated wildcard ACM cert (*.spiresen.com + apex), for future CloudFront distributions."
  value       = module.dns.certificate_arn
}
