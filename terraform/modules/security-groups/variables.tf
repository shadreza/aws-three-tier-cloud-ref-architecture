variable "name" {
  description = "Prefix for every resource name, for example uptime-dev."
  type        = string
}

variable "vpc_id" {
  type = string
}

variable "app_port" {
  description = "The port the API container listens on."
  type        = number
  default     = 8080
}

variable "db_port" {
  type    = number
  default = 3306
}

variable "alb_listener_ports" {
  description = "Ports the load balancer listens on. 80 for HTTP; add 443 once there is a certificate."
  type        = list(number)
  default     = [80]
}

variable "alb_ingress_cidrs" {
  description = <<-EOT
    IPv4 ranges allowed to reach the load balancer directly. In step 04 this is
    your own IP (x.x.x.x/32) for testing. From step 05 on it is empty, and only
    CloudFront may connect (alb_allow_cloudfront).
  EOT
  type        = list(string)
  default     = []
}

variable "alb_allow_cloudfront" {
  description = "Allow CloudFront's origin-facing addresses to reach the load balancer (step 05)."
  type        = bool
  default     = false

  # The CloudFront prefix list counts as about 55 rules for each port it is
  # used with, and a security group allows 60 rules by default. Two ports would
  # not fit.
  validation {
    condition     = !var.alb_allow_cloudfront || length(var.alb_listener_ports) == 1
    error_message = "With alb_allow_cloudfront, use exactly one listener port (80, or 443 with a certificate)."
  }
}
