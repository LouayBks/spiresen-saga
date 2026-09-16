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

variable "app_domain_name" {
  description = "Hostname the frontend is served on. One label under domain_name, so it's covered by module.dns's wildcard cert without needing a new one."
  type        = string
  default     = "athar.spiresen.com"
}

variable "static_site_bucket_name" {
  description = "S3 bucket name for the compiled frontend bundle."
  type        = string
  default     = "spiresen-saga-frontend"
}

variable "api_function_name" {
  description = "Lambda function name for the backend API."
  type        = string
  default     = "spiresen-saga-api"
}

variable "lambda_zip_path" {
  description = "Path to the backend's pre-built Lambda deployment zip (see backend/build_lambda.sh). Relative to this directory — CI's working-directory is infra/environments/prod when this is evaluated."
  type        = string
  default     = "../../../backend/dist/lambda.zip"
}
