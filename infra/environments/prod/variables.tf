variable "aws_region" {
  description = "Primary AWS region for this environment's resources (Paris). ACM's wildcard cert is always us-east-1 regardless, per CloudFront's requirement — handled via the aws.us_east_1 provider alias, not this variable."
  type        = string
  default     = "eu-west-3"
}

variable "domain_name" {
  description = "Root domain for this environment (e.g. spiresen.com)."
  type        = string
  default     = "spiresen.com"
}
