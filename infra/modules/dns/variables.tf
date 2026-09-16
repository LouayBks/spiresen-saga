variable "domain_name" {
  description = "Root domain to host a Route 53 zone and wildcard ACM cert for (e.g. spiresen.com)."
  type        = string
}

variable "tags" {
  description = "Tags applied to every resource this module creates."
  type        = map(string)
  default     = {}
}
