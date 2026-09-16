variable "bucket_name" {
  description = "S3 bucket name for the compiled SPA. Must start with 'spiresen-saga-' — the CI deploy role's S3 permissions are scoped to that prefix, so anything else fails at apply time with a confusing AccessDenied rather than here."
  type        = string

  validation {
    condition     = can(regex("^spiresen-saga-", var.bucket_name))
    error_message = "bucket_name must start with \"spiresen-saga-\" to match the CI deploy role's IAM scope."
  }
}

variable "domain_name" {
  description = "Optional custom domain to serve this site on (e.g. athar.spiresen.com). When null, CloudFront's own default domain/cert is used and no Route 53 record is created."
  type        = string
  default     = null
}

variable "certificate_arn" {
  description = "ACM cert (us-east-1, already validated) covering domain_name. Required when domain_name is set — this module never creates a cert itself, callers own that."
  type        = string
  default     = null
}

variable "route53_zone_id" {
  description = "Route 53 zone to create the domain_name alias record in. Required when domain_name is set."
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags applied to every resource this module creates."
  type        = map(string)
  default     = {}
}
