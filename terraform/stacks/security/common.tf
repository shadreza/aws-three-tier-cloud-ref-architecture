# The same four variables exist in every stack. Their values come from
# envs/<env>/common.tfvars.

variable "project" {
  description = "Short name used in every resource name."
  type        = string
}

variable "environment" {
  description = "dev, staging or prod."
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be dev, staging or prod."
  }
}

variable "region" {
  type = string
}

variable "account_id" {
  description = "The AWS account this environment lives in."
  type        = string
}

locals {
  name = "${var.project}-${var.environment}"

  # Made by terraform/bootstrap. Other stacks' state is read from here.
  state_bucket = "${var.project}-tfstate-${var.account_id}"
}
