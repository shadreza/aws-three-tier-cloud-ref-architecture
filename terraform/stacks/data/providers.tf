provider "aws" {
  region = var.region

  # A safety net: if your terminal points at the wrong account, Terraform
  # stops before it changes anything.
  allowed_account_ids = [var.account_id]

  default_tags {
    tags = {
      Project     = var.project
      Environment = var.environment
      Stack       = "data"
      ManagedBy   = "terraform"
    }
  }
}
