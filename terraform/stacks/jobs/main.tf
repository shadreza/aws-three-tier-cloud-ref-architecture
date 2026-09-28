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

  jobs = {
    check = {
      task_definition = local.compute.check_task_definition_arn_latest
      schedule        = var.check_schedule
      # The next run is a minute away; retrying an old one only adds load.
      retries = 0
      max_age = 60
    }
    rollup = {
      task_definition = local.compute.rollup_task_definition_arn_latest
      schedule        = var.rollup_schedule
      retries         = 2
      max_age         = 3600
    }
  }
}

# ---- the role the scheduler uses to start tasks -------------------------------------

data "aws_iam_policy_document" "scheduler_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["scheduler.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [var.account_id]
    }
  }
}

resource "aws_iam_role" "scheduler" {
  name               = "${local.name}-scheduler"
  assume_role_policy = data.aws_iam_policy_document.scheduler_assume.json
}

data "aws_iam_policy_document" "scheduler" {
  # Start only our two task definitions, only in our cluster. The schedule
  # names the task definition without a revision, so allow that form and the
  # revision it resolves to.
  statement {
    actions   = ["ecs:RunTask"]
    resources = flatten([for j in local.jobs : [j.task_definition, "${j.task_definition}:*"]])
    condition {
      test     = "ArnEquals"
      variable = "ecs:cluster"
      values   = [local.compute.cluster_arn]
    }
  }

  # Needed because the tasks get ECS-managed tags.
  statement {
    actions   = ["ecs:TagResource"]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "ecs:CreateAction"
      values   = ["RunTask"]
    }
  }

  # Starting a task means handing it its two roles. PassRole says the
  # scheduler may do that, but only to ECS tasks.
  statement {
    actions   = ["iam:PassRole"]
    resources = [local.compute.execution_role_arn, local.compute.jobs_task_role_arn]
    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values   = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy" "scheduler" {
  name   = "run-job-tasks"
  role   = aws_iam_role.scheduler.id
  policy = data.aws_iam_policy_document.scheduler.json
}

# ---- the schedules ---------------------------------------------------------------------

resource "aws_scheduler_schedule_group" "this" {
  name = local.name
}

resource "aws_scheduler_schedule" "job" {
  for_each = local.jobs

  name        = each.key
  group_name  = aws_scheduler_schedule_group.this.name
  description = "Start the ${each.key} task in ${local.name}"
  state       = var.schedules_enabled ? "ENABLED" : "DISABLED"

  schedule_expression          = each.value.schedule
  schedule_expression_timezone = "Asia/Tokyo"

  # Run exactly on time, not somewhere in a window.
  flexible_time_window {
    mode = "OFF"
  }

  target {
    arn      = local.compute.cluster_arn
    role_arn = aws_iam_role.scheduler.arn

    ecs_parameters {
      task_definition_arn     = each.value.task_definition
      launch_type             = "FARGATE"
      platform_version        = "LATEST"
      task_count              = 1
      enable_ecs_managed_tags = true
      propagate_tags          = "TASK_DEFINITION"

      network_configuration {
        subnets          = local.net.private_subnet_ids
        security_groups  = [local.sec.jobs_sg_id]
        assign_public_ip = false
      }
    }

    retry_policy {
      maximum_retry_attempts       = each.value.retries
      maximum_event_age_in_seconds = each.value.max_age
    }
  }
}
