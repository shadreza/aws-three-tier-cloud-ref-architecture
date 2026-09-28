# A web application firewall for CloudFront. CloudFront is global, so its WAF
# must be created in us-east-1: the caller passes that provider in.

variable "name" {
  type = string
}

variable "rate_limit_per_5_min" {
  description = "Requests one IP may send in 5 minutes before it is blocked for a while."
  type        = number
  default     = 2000
}

resource "aws_wafv2_web_acl" "this" {
  name  = var.name
  scope = "CLOUDFRONT"

  default_action {
    allow {}
  }

  # 1. Too many requests from one address: block it for a while.
  rule {
    name     = "rate-limit-per-ip"
    priority = 10
    action {
      block {}
    }
    statement {
      rate_based_statement {
        limit              = var.rate_limit_per_5_min
        aggregate_key_type = "IP"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "rate-limit-per-ip"
      sampled_requests_enabled   = true
    }
  }

  # 2. Addresses AWS has seen doing bad things (bots, scanners).
  rule {
    name     = "aws-ip-reputation"
    priority = 20
    override_action {
      none {}
    }
    statement {
      managed_rule_group_statement {
        vendor_name = "AWS"
        name        = "AWSManagedRulesAmazonIpReputationList"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "aws-ip-reputation"
      sampled_requests_enabled   = true
    }
  }

  # 3. Common attacks: cross-site scripting, path traversal, huge bodies...
  rule {
    name     = "aws-common"
    priority = 30
    override_action {
      none {}
    }
    statement {
      managed_rule_group_statement {
        vendor_name = "AWS"
        name        = "AWSManagedRulesCommonRuleSet"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "aws-common"
      sampled_requests_enabled   = true
    }
  }

  # 4. Request patterns known to exploit software bugs (Log4j and friends).
  rule {
    name     = "aws-known-bad-inputs"
    priority = 40
    override_action {
      none {}
    }
    statement {
      managed_rule_group_statement {
        vendor_name = "AWS"
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "aws-known-bad-inputs"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = var.name
    sampled_requests_enabled   = true
  }
}

output "arn" {
  value = aws_wafv2_web_acl.this.arn
}

output "name" {
  value = aws_wafv2_web_acl.this.name
}
