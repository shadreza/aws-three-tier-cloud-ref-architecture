# The role GitHub Actions uses to deploy this environment. It has no keys:
# GitHub hands the workflow a signed token, and AWS swaps it for temporary
# credentials, but only for a job that runs in this repository *and* in the
# GitHub environment with the same name (dev, staging, prod).
#
# What the role may do is just a deploy:
#   push an image to this environment's ECR repository
#   choose the image tag in SSM
#   run Terraform for the compute stack (read all state, write compute's)
#   upload the web app and invalidate CloudFront
# It cannot change the network, the database, IAM or anything else. If a plan
# wants to, the apply fails, which is what we want.

data "terraform_remote_state" "registry" {
  backend = "s3"
  config = {
    bucket = local.state_bucket
    key    = "${var.environment}/registry.tfstate"
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

data "terraform_remote_state" "edge" {
  backend = "s3"
  config = {
    bucket = local.state_bucket
    key    = "${var.environment}/edge.tfstate"
    region = var.region
  }
}

data "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"
}

locals {
  registry = data.terraform_remote_state.registry.outputs
  compute  = data.terraform_remote_state.compute.outputs
  edge     = data.terraform_remote_state.edge.outputs

  state_arn = "arn:aws:s3:::${local.state_bucket}"
  arn_part  = "${var.region}:${var.account_id}"
}

data "aws_iam_policy_document" "trust" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [data.aws_iam_openid_connect_provider.github.arn]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
    # Only jobs that declare `environment: <env>` in this repository.
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.github_repository}:environment:${var.environment}"]
    }
  }
}

resource "aws_iam_role" "deploy" {
  name                 = "${local.name}-github-deploy"
  assume_role_policy   = data.aws_iam_policy_document.trust.json
  max_session_duration = 3600
}

data "aws_iam_policy_document" "deploy" {
  # ---- image ----
  statement {
    sid       = "EcrLogin"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }
  statement {
    sid = "EcrPush"
    actions = [
      "ecr:BatchCheckLayerAvailability", "ecr:InitiateLayerUpload", "ecr:UploadLayerPart",
      "ecr:CompleteLayerUpload", "ecr:PutImage", "ecr:BatchGetImage", "ecr:DescribeImages",
    ]
    resources = [local.registry.backend_repository_arn]
  }
  statement {
    sid       = "ChooseImageTag"
    actions   = ["ssm:GetParameter", "ssm:GetParameters", "ssm:PutParameter"]
    resources = ["arn:aws:ssm:${local.arn_part}:parameter/${local.name}/image-tag"]
  }

  # ---- Terraform state ----
  statement {
    sid       = "ListState"
    actions   = ["s3:ListBucket"]
    resources = [local.state_arn]
    # env:/ is where the S3 backend looks for workspaces. terraform init and
    # every remote state read list it, even though we only use the default
    # workspace.
    condition {
      test     = "StringLike"
      variable = "s3:prefix"
      values   = ["${var.environment}/*", "env:/*"]
    }
  }
  statement {
    sid       = "ReadEnvironmentState"
    actions   = ["s3:GetObject"]
    resources = ["${local.state_arn}/${var.environment}/*"]
  }
  statement {
    sid     = "WriteComputeState"
    actions = ["s3:PutObject", "s3:DeleteObject"]
    resources = [
      "${local.state_arn}/${var.environment}/compute.tfstate",
      "${local.state_arn}/${var.environment}/compute.tfstate.tflock",
    ]
  }

  # ---- what a compute plan reads ----
  statement {
    sid = "ReadComputeResources"
    actions = [
      "ecs:Describe*", "ecs:List*",
      "elasticloadbalancing:Describe*",
      "iam:GetRole", "iam:GetRolePolicy", "iam:ListRolePolicies", "iam:ListAttachedRolePolicies", "iam:ListRoleTags",
      "logs:DescribeLogGroups", "logs:ListTagsForResource", "logs:ListTagsLogGroup",
      "application-autoscaling:Describe*", "application-autoscaling:ListTagsForResource",
      "ssm:DescribeParameters",
    ]
    resources = ["*"]
  }

  # ---- what a deploy changes ----
  statement {
    sid       = "RegisterTaskDefinitions"
    actions   = ["ecs:RegisterTaskDefinition", "ecs:DeregisterTaskDefinition", "ecs:TagResource"]
    resources = ["*"] # RegisterTaskDefinition does not support resource-level permissions
  }
  statement {
    sid       = "UpdateApiService"
    actions   = ["ecs:UpdateService"]
    resources = ["arn:aws:ecs:${local.arn_part}:service/${local.compute.cluster_name}/${local.compute.api_service_name}"]
  }
  statement {
    sid       = "HandTasksTheirRoles"
    actions   = ["iam:PassRole"]
    resources = ["arn:aws:iam::${var.account_id}:role/${local.name}-*"]
    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values   = ["ecs-tasks.amazonaws.com"]
    }
  }

  # ---- web app ----
  statement {
    sid       = "ListWebBucket"
    actions   = ["s3:ListBucket"]
    resources = ["arn:aws:s3:::${local.edge.web_bucket}"]
  }
  statement {
    sid       = "UploadWebFiles"
    actions   = ["s3:PutObject", "s3:DeleteObject", "s3:GetObject"]
    resources = ["arn:aws:s3:::${local.edge.web_bucket}/*"]
  }
  statement {
    sid       = "InvalidateCache"
    actions   = ["cloudfront:CreateInvalidation", "cloudfront:GetInvalidation"]
    resources = ["arn:aws:cloudfront::${var.account_id}:distribution/${local.edge.distribution_id}"]
  }
}

resource "aws_iam_role_policy" "deploy" {
  name   = "deploy"
  role   = aws_iam_role.deploy.id
  policy = data.aws_iam_policy_document.deploy.json
}
