variable "name" {
  type = string
}

variable "web_bucket_regional_domain_name" {
  description = "bucket.s3.region.amazonaws.com. Passed as text, not from the bucket resource, because the bucket policy needs this distribution's ARN."
  type        = string
}

variable "alb_arn" {
  description = "The internal load balancer CloudFront reaches through a VPC origin."
  type        = string
}

variable "alb_dns_name" {
  type = string
}

variable "alb_port" {
  type    = number
  default = 80
}

variable "web_acl_arn" {
  type = string
}

variable "price_class" {
  description = "PriceClass_200 includes edge locations in Japan and the rest of Asia. PriceClass_100 does not."
  type        = string
  default     = "PriceClass_200"
}

variable "domain_name" {
  description = "Optional, for example uptime.example.com. Empty uses the free dxxxx.cloudfront.net name."
  type        = string
  default     = ""
}

variable "hosted_zone_id" {
  description = "Route 53 hosted zone that holds domain_name. Needed only with a domain."
  type        = string
  default     = ""
}
