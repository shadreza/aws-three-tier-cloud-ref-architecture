variable "name" {
  description = "Prefix for every resource name, for example uptime-dev."
  type        = string
}

variable "cidr" {
  description = "The VPC address range. Must be a /16 so each subnet can be a /24."
  type        = string

  validation {
    condition     = can(cidrhost(var.cidr, 0)) && endswith(var.cidr, "/16")
    error_message = "cidr must be a valid /16 range, for example 10.20.0.0/16."
  }
}

variable "azs" {
  description = "Availability Zones to use. Two is the minimum for a load balancer and for RDS Multi-AZ."
  type        = list(string)

  validation {
    condition     = length(var.azs) >= 2 && length(var.azs) <= 3
    error_message = "Use two or three Availability Zones."
  }
}

variable "nat_gateway_mode" {
  description = <<-EOT
    How private subnets reach the internet:
      single  one NAT gateway for all zones (cheaper, one zone can break outbound traffic)
      per_az  one NAT gateway in each zone (survives a zone failure, costs more)
      none    no NAT gateway (private subnets have no internet at all)
  EOT
  type        = string
  default     = "single"

  validation {
    condition     = contains(["single", "per_az", "none"], var.nat_gateway_mode)
    error_message = "nat_gateway_mode must be single, per_az or none."
  }
}

variable "enable_s3_endpoint" {
  description = "Add a free S3 gateway endpoint so S3 traffic (including container image layers) skips the NAT gateway."
  type        = bool
  default     = true
}
