output "static_site_bucket_name" {
  description = "Frontend S3 bucket name — set as the STATIC_SITE_BUCKET_NAME GitHub Actions variable (dev environment)."
  value       = module.static_site.bucket_name
}

output "static_site_distribution_id" {
  description = "Frontend CloudFront distribution ID — set as the STATIC_SITE_DISTRIBUTION_ID GitHub Actions variable (dev environment)."
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

output "app_certificate_arn" {
  description = "ACM cert covering dev.athar.spiresen.com."
  value       = aws_acm_certificate_validation.app.certificate_arn
}
