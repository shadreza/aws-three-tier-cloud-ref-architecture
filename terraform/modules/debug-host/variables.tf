variable "name" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "subnet_id" {
  description = "A private subnet. The host has no public IP."
  type        = string
}

variable "instance_type" {
  type    = string
  default = "t4g.nano"
}
