variable "alb_listener_ports" {
  description = "80 without a domain, 443 with one."
  type        = list(number)
  default     = [80]
}

variable "alb_ingress_cidrs" {
  description = "Your own IP as x.x.x.x/32 while testing in step 04. Empty once CloudFront is in front (step 05)."
  type        = list(string)
  default     = []
}

variable "alb_allow_cloudfront" {
  description = "true from step 05 on."
  type        = bool
  default     = false
}
