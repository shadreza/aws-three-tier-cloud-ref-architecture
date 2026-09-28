variable "alb_ingress_cidrs" {
  description = "Extra ranges (for example a VPN) allowed to reach the internal load balancer. Usually empty."
  type        = list(string)
  default     = []
}

variable "enable_debug_host" {
  description = "A t4g.nano inside the VPC for connecting to RDS and the internal load balancer (steps 03 to 07). About $0.005 an hour."
  type        = bool
  default     = false
}
