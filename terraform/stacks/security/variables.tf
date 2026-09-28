variable "alb_ingress_cidrs" {
  description = "Extra ranges (for example a VPN) allowed to reach the internal load balancer. Usually empty."
  type        = list(string)
  default     = []
}
