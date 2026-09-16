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

output "static_site_bucket_name" {
  description = "Frontend S3 bucket name — set as the STATIC_SITE_BUCKET_NAME GitHub Actions variable (prod environment)."
  value       = module.static_site.bucket_name
}

output "static_site_distribution_id" {
  description = "Frontend CloudFront distribution ID — set as the STATIC_SITE_DISTRIBUTION_ID GitHub Actions variable (prod environment)."
  value       = module.static_site.distribution_id
}

output "static_site_distribution_domain_name" {
  description = "Frontend's *.cloudfront.net domain (the app_domain_name alias record points here)."
  value       = module.static_site.distribution_domain_name
}

output "api_invoke_url" {
  description = "Backend API Gateway invoke URL."
  value       = module.api.invoke_url
}
