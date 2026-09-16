variable "aws_region" {
  description = "Primary AWS region for this environment's resources (Paris)."
  type        = string
  default     = "eu-west-3"
}

variable "route53_zone_id" {
  description = "The spiresen.com hosted zone's ID. This environment doesn't own the zone (module.dns, called once from environments/prod, does) — this is the same cross-environment literal-duplication pattern versions.tf's state-bucket-name comment already documents, since Terraform backend/state config can't reference another environment's outputs without remote-state coupling. Looked up via `aws route53 list-hosted-zones`; must match environments/prod's module.dns.zone_id output."
  type        = string
  default     = "Z06423173BGNAX9NB2W1C"
}

variable "app_domain_name" {
  description = "Hostname the frontend is served on. Two labels under spiresen.com, so it's NOT covered by the existing *.spiresen.com wildcard cert — this environment requests its own single-SAN cert for exactly this name."
  type        = string
  default     = "dev.athar.spiresen.com"
}

variable "static_site_bucket_name" {
  description = "S3 bucket name for the compiled frontend bundle."
  type        = string
  default     = "spiresen-saga-frontend-int"
}

variable "api_function_name" {
  description = "Lambda function name for the backend API."
  type        = string
  default     = "spiresen-saga-api-int"
}

variable "lambda_zip_path" {
  description = "Path to the backend's pre-built Lambda deployment zip (see backend/build_lambda.sh). Relative to this directory — CI's working-directory is infra/environments/int when this is evaluated."
  type        = string
  default     = "../../../backend/dist/lambda.zip"
}
