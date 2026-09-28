variable "vpc_cidr" {
  description = "Give each environment its own range so they could be connected later without clashes."
  type        = string
}

variable "azs" {
  description = "Availability Zones. In Tokyo, ap-northeast-1b does not exist for new accounts; use 1a, 1c, 1d."
  type        = list(string)
}

variable "nat_gateway_mode" {
  description = "single, per_az or none. See docs/adr/0006-nat-gateways-per-environment.md."
  type        = string
}
