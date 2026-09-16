variable "aws_region" {
  description = "Region for the state bucket and lock table — matches the stack's primary region (Paris), independent of ACM's forced us-east-1."
  type        = string
  default     = "eu-west-3"
}

variable "state_bucket_name" {
  description = "Globally-unique S3 bucket name for Terraform remote state."
  type        = string
  default     = "spiresen-saga-tfstate"
}
