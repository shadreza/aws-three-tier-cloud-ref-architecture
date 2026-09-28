# The bucket that stores Terraform state for every environment in one AWS
# account. It is the only thing we cannot create with remote state (it would
# have to store its own state), so this stack keeps a local state file.
#
# Run it once per AWS account:
#
#   make tf-bootstrap account_id=123456789012 budget_email=you@example.com
#
# It also sets up a monthly cost budget that emails you, because a forgotten
# NAT gateway or database costs real money.
#
# See docs/steps/02-aws-network.md, section 8.2.

terraform {
  required_version = ">= 1.11"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

variable "account_id" {
  description = "The AWS account this bucket belongs to. Terraform refuses to run against any other account."
  type        = string
}

variable "region" {
  description = "Region for the state bucket. Keep it next to the workloads."
  type        = string
  default     = "ap-northeast-1"
}

variable "project" {
  description = "Short name used in every resource name."
  type        = string
  default     = "uptime"
}

variable "budget_email" {
  description = "Where budget alerts go. Leave empty to skip the budget."
  type        = string
  default     = ""
}

variable "budget_usd" {
  description = "Monthly budget for the whole account, in US dollars."
  type        = number
  default     = 50
}

provider "aws" {
  region              = var.region
  allowed_account_ids = [var.account_id]

  default_tags {
    tags = {
      Project   = var.project
      Stack     = "bootstrap"
      ManagedBy = "terraform"
    }
  }
}

# Bucket names are global across all AWS customers, so the account ID makes
# ours unique.
resource "aws_s3_bucket" "state" {
  bucket = "${var.project}-tfstate-${var.account_id}"

  # Losing this bucket means Terraform forgets everything it built.
  lifecycle {
    prevent_destroy = true
  }
}

# Every change to a state file keeps the old copy, so a bad apply can be
# rolled back by restoring an older version.
resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.state.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "state" {
  bucket                  = aws_s3_bucket.state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Old versions pile up with every apply. Keep them for 90 days.
resource "aws_s3_bucket_lifecycle_configuration" "state" {
  bucket = aws_s3_bucket.state.id

  rule {
    id     = "expire-old-versions"
    status = "Enabled"
    filter {}
    noncurrent_version_expiration {
      noncurrent_days = 90
    }
  }
}

# State files can hold secrets (connection strings, generated names), so only
# encrypted connections are allowed.
data "aws_iam_policy_document" "tls_only" {
  statement {
    sid     = "DenyInsecureTransport"
    effect  = "Deny"
    actions = ["s3:*"]
    resources = [
      aws_s3_bucket.state.arn,
      "${aws_s3_bucket.state.arn}/*",
    ]
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "state" {
  bucket = aws_s3_bucket.state.id
  policy = data.aws_iam_policy_document.tls_only.json

  depends_on = [aws_s3_bucket_public_access_block.state]
}

# Emails you at 50%, 80% and 100% of the budget (actual spend), and when the
# forecast says the month will go over. The first two budgets are free.
resource "aws_budgets_budget" "monthly" {
  count = var.budget_email == "" ? 0 : 1

  name         = "${var.project}-monthly"
  budget_type  = "COST"
  limit_amount = tostring(var.budget_usd)
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  dynamic "notification" {
    for_each = [50, 80, 100]
    content {
      comparison_operator        = "GREATER_THAN"
      threshold                  = notification.value
      threshold_type             = "PERCENTAGE"
      notification_type          = "ACTUAL"
      subscriber_email_addresses = [var.budget_email]
    }
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "FORECASTED"
    subscriber_email_addresses = [var.budget_email]
  }
}

output "state_bucket" {
  description = "Put this name in terraform/envs/<env>/backend.hcl and common.tfvars."
  value       = aws_s3_bucket.state.bucket
}
