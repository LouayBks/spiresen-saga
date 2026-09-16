variable "function_name" {
  description = "Lambda function name. Must start with 'spiresen-saga-' — its execution role (function_name + \"-exec\") must too, since the CI deploy role's IAM permissions are scoped to that prefix."
  type        = string

  validation {
    condition     = can(regex("^spiresen-saga-", var.function_name))
    error_message = "function_name must start with \"spiresen-saga-\" to match the CI deploy role's IAM scope."
  }
}

variable "lambda_zip_path" {
  description = "Path to a pre-built deployment zip (app code + installed deps — see backend/build_lambda.sh). This module doesn't run pip install itself."
  type        = string
}

variable "timeout" {
  description = "Lambda timeout, seconds."
  type        = number
  default     = 10
}

variable "memory_size" {
  description = "Lambda memory, MB."
  type        = number
  default     = 256
}

variable "tags" {
  description = "Tags applied to every resource this module creates."
  type        = map(string)
  default     = {}
}
