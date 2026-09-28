provider "aws" {
  region              = var.region
  allowed_account_ids = [var.account_id]

  default_tags {
    tags = {
      Project     = var.project
      Environment = var.environment
      Stack       = "edge"
      ManagedBy   = "terraform"
    }
  }
}

# CloudFront is global, and its WAF and certificates must live in us-east-1.
provider "aws" {
  alias               = "us_east_1"
  region              = "us-east-1"
  allowed_account_ids = [var.account_id]

  default_tags {
    tags = {
      Project     = var.project
      Environment = var.environment
      Stack       = "edge"
      ManagedBy   = "terraform"
    }
  }
}
