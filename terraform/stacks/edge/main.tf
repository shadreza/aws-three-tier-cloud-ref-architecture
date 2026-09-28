data "terraform_remote_state" "network" {
  backend = "s3"
  config = {
    bucket = local.state_bucket
    key    = "${var.environment}/network.tfstate"
    region = var.region
  }
}

data "terraform_remote_state" "security" {
  backend = "s3"
  config = {
    bucket = local.state_bucket
    key    = "${var.environment}/security.tfstate"
    region = var.region
  }
}

data "terraform_remote_state" "compute" {
  backend = "s3"
  config = {
    bucket = local.state_bucket
    key    = "${var.environment}/compute.tfstate"
    region = var.region
  }
}

locals {
  net     = data.terraform_remote_state.network.outputs
  sec     = data.terraform_remote_state.security.outputs
  compute = data.terraform_remote_state.compute.outputs
}

# ---- the firewall (us-east-1) -------------------------------------------------------

module "waf" {
  source    = "../../modules/waf-cloudfront"
  providers = { aws = aws.us_east_1 }

  name                 = local.name
  rate_limit_per_5_min = var.waf_rate_limit_per_5_min
}

# ---- the web bucket -------------------------------------------------------------------

# Only this distribution may read the files. The policy names the distribution,
# so another CloudFront distribution (even in another AWS account) cannot.
data "aws_iam_policy_document" "cloudfront_read" {
  statement {
    sid       = "CloudFrontReadsWebFiles"
    actions   = ["s3:GetObject"]
    resources = ["arn:aws:s3:::${local.name}-web-${var.account_id}/*"]
    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [module.cdn.distribution_arn]
    }
  }
}

module "web" {
  source = "../../modules/private-bucket"

  name              = "${local.name}-web-${var.account_id}"
  force_destroy     = var.web_force_destroy
  extra_policy_json = data.aws_iam_policy_document.cloudfront_read.json
}

# ---- CloudFront -----------------------------------------------------------------------

module "cdn" {
  source    = "../../modules/cdn"
  providers = { aws = aws, aws.us_east_1 = aws.us_east_1 }

  name                            = local.name
  web_bucket_regional_domain_name = "${local.name}-web-${var.account_id}.s3.${var.region}.amazonaws.com"
  alb_arn                         = local.compute.alb_arn
  alb_dns_name                    = local.compute.alb_dns_name
  alb_port                        = local.sec.alb_port
  web_acl_arn                     = module.waf.arn
  price_class                     = var.price_class
  domain_name                     = var.domain_name
  hosted_zone_id                  = var.hosted_zone_id
}

# ---- let CloudFront's VPC origin reach the load balancer ---------------------------------
#
# When the VPC origin is created, CloudFront adds a security group called
# CloudFront-VPCOrigins-Service-SG to our VPC and puts its network interfaces
# in it. The load balancer accepts traffic from that group and nothing else
# from outside the VPC.

data "aws_security_group" "cloudfront_vpc_origin" {
  vpc_id = local.net.vpc_id
  name   = "CloudFront-VPCOrigins-Service-SG"

  depends_on = [module.cdn]
}

resource "aws_vpc_security_group_ingress_rule" "alb_from_cloudfront" {
  security_group_id            = local.sec.alb_sg_id
  description                  = "HTTP from the CloudFront VPC origin"
  referenced_security_group_id = data.aws_security_group.cloudfront_vpc_origin.id
  from_port                    = local.sec.alb_port
  to_port                      = local.sec.alb_port
  ip_protocol                  = "tcp"
}
