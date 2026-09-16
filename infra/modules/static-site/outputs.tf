output "bucket_name" {
  description = "S3 bucket name — the sync target for a frontend deploy workflow."
  value       = aws_s3_bucket.site.id
}

output "bucket_arn" {
  description = "S3 bucket ARN."
  value       = aws_s3_bucket.site.arn
}

output "distribution_id" {
  description = "CloudFront distribution ID — used for cache invalidation after a deploy."
  value       = aws_cloudfront_distribution.site.id
}

output "distribution_domain_name" {
  description = "CloudFront's own *.cloudfront.net domain (always valid, even when domain_name/aliases are set)."
  value       = aws_cloudfront_distribution.site.domain_name
}
