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

variable "alb_port" {
  description = "The port the internal load balancer listens on."
  type        = number
  default     = 80
}

variable "alb_ingress_cidrs" {
  description = <<-EOT
    Extra IPv4 ranges allowed to reach the internal load balancer, for example
    a VPN range. Usually empty: CloudFront gets its own rule in the edge stack
    (step 05) and the debug host in the security stack.
  EOT
  type        = list(string)
  default     = []
}
