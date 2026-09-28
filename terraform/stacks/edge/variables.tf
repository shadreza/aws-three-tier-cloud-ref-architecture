variable "domain_name" {
  description = "Optional custom name, for example uptime.example.com. Empty uses dxxxx.cloudfront.net."
  type        = string
  default     = ""
}

variable "hosted_zone_id" {
  description = "The Route 53 hosted zone for domain_name. Only needed with a domain."
  type        = string
  default     = ""
}

variable "price_class" {
  type    = string
  default = "PriceClass_200"
}

variable "waf_rate_limit_per_5_min" {
  type    = number
  default = 2000
}

variable "web_force_destroy" {
  type = bool
}
