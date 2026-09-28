# ---- inputs from the stacks below ---------------------------------------------

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

data "terraform_remote_state" "data" {
  backend = "s3"
  config = {
    bucket = local.state_bucket
    key    = "${var.environment}/data.tfstate"
    region = var.region
  }
}

data "terraform_remote_state" "registry" {
  backend = "s3"
  config = {
    bucket = local.state_bucket
    key    = "${var.environment}/registry.tfstate"
    region = var.region
  }
}

# Which image to run. It is a parameter in SSM, not a Terraform variable, so
# whoever deploys (you in step 04, GitHub Actions from step 08) sets it once
# and every later apply uses the same image. See ADR 0011.
data "aws_ssm_parameter" "image_tag" {
  name = "/${local.name}/image-tag"
}

locals {
  net      = data.terraform_remote_state.network.outputs
  sec      = data.terraform_remote_state.security.outputs
  db       = data.terraform_remote_state.data.outputs
  image    = "${data.terraform_remote_state.registry.outputs.backend_repository_url}:${nonsensitive(data.aws_ssm_parameter.image_tag.value)}"
  api_port = 8080
}

# ---- cluster and logs -----------------------------------------------------------

resource "aws_ecs_cluster" "this" {
  name = local.name

  # Container Insights adds per-task metrics for a fee. Step 07 discusses it.
  setting {
    name  = "containerInsights"
    value = "disabled"
  }
}

resource "aws_cloudwatch_log_group" "api" {
  name              = "/ecs/${local.name}/api"
  retention_in_days = var.log_retention_days
}

resource "aws_cloudwatch_log_group" "jobs" {
  name              = "/ecs/${local.name}/jobs"
  retention_in_days = var.log_retention_days
}

# ---- IAM roles ------------------------------------------------------------------
#
# Two kinds of role, often mixed up:
#   execution role  used by ECS itself before the app starts: pull the image,
#                   read the secrets into environment variables, create logs
#   task role       used by the app inside the container: here, S3 for reports

data "aws_iam_policy_document" "ecs_tasks_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
    # Only tasks from this account may use the roles.
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [var.account_id]
    }
  }
}

resource "aws_iam_role" "execution" {
  name               = "${local.name}-ecs-execution"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_assume.json
}

resource "aws_iam_role_policy_attachment" "execution_managed" {
  role       = aws_iam_role.execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

data "aws_iam_policy_document" "execution_secrets" {
  statement {
    actions   = ["secretsmanager:GetSecretValue"]
    resources = [local.db.db_secret_arn, local.db.admin_token_secret_arn]
  }
}

resource "aws_iam_role_policy" "execution_secrets" {
  name   = "read-app-secrets"
  role   = aws_iam_role.execution.id
  policy = data.aws_iam_policy_document.execution_secrets.json
}

resource "aws_iam_role" "api" {
  name               = "${local.name}-api-task"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_assume.json
}

data "aws_iam_policy_document" "api_reports" {
  # Not limited to a prefix on purpose: S3 only answers "no such key" (404)
  # to callers that may list the bucket. With a prefix condition, a missing
  # report would come back as "access denied" and the API would return 500.
  # The bucket holds nothing but reports.
  statement {
    sid       = "ListReports"
    actions   = ["s3:ListBucket"]
    resources = [local.db.reports_bucket_arn]
  }
  statement {
    sid       = "ReadReports"
    actions   = ["s3:GetObject"]
    resources = ["${local.db.reports_bucket_arn}/reports/*"]
  }
}

resource "aws_iam_role_policy" "api_reports" {
  name   = "read-reports"
  role   = aws_iam_role.api.id
  policy = data.aws_iam_policy_document.api_reports.json
}

resource "aws_iam_role" "jobs" {
  name               = "${local.name}-jobs-task"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_assume.json
}

data "aws_iam_policy_document" "jobs_reports" {
  statement {
    sid       = "WriteReports"
    actions   = ["s3:PutObject"]
    resources = ["${local.db.reports_bucket_arn}/reports/*"]
  }
}

resource "aws_iam_role_policy" "jobs_reports" {
  name   = "write-reports"
  role   = aws_iam_role.jobs.id
  policy = data.aws_iam_policy_document.jobs_reports.json
}

# ---- container settings -----------------------------------------------------------

locals {
  # The same settings for every command, from the environment (ADR config rule).
  app_environment = [
    { name = "DB_HOST", value = local.db.db_address },
    { name = "DB_PORT", value = tostring(local.db.db_port) },
    { name = "DB_USER", value = local.db.db_username },
    { name = "DB_NAME", value = local.db.db_name },
    { name = "DB_TLS_CA", value = "/app/certs/rds-global-bundle.pem" },
    { name = "REPORT_BUCKET", value = local.db.reports_bucket },
    { name = "HTTP_PORT", value = tostring(local.api_port) },
    { name = "ALLOW_PRIVATE_TARGETS", value = "false" },
    { name = "CHECK_TIMEOUT", value = var.check_timeout },
    { name = "CHECK_CONCURRENCY", value = tostring(var.check_concurrency) },
    { name = "RETENTION_DAYS", value = tostring(var.retention_days) },
    { name = "AWS_REGION", value = var.region },
  ]

  # ECS reads these from Secrets Manager when the task starts and puts them in
  # the environment. They never appear in the task definition.
  app_secrets = [
    { name = "DB_PASSWORD", valueFrom = "${local.db.db_secret_arn}:password::" },
    { name = "ADMIN_TOKEN", valueFrom = local.db.admin_token_secret_arn },
  ]

  log_options = {
    for k, g in { api = aws_cloudwatch_log_group.api.name, jobs = aws_cloudwatch_log_group.jobs.name } :
    k => {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = g
        "awslogs-region"        = var.region
        "awslogs-stream-prefix" = "app"
        # Do not block the app if CloudWatch is slow; drop logs instead.
        "mode"            = "non-blocking"
        "max-buffer-size" = "4m"
      }
    }
  }

  base_container = {
    image                  = local.image
    essential              = true
    readonlyRootFilesystem = true
    environment            = local.app_environment
    secrets                = local.app_secrets
  }
}

# ---- the API service ----------------------------------------------------------------

module "alb" {
  source = "../../modules/internal-alb"

  name                = local.name
  vpc_id              = local.net.vpc_id
  subnet_ids          = local.net.private_subnet_ids
  security_group_id   = local.sec.alb_sg_id
  listener_port       = local.sec.alb_port
  target_port         = local.api_port
  deletion_protection = var.alb_deletion_protection
}

module "api" {
  source = "../../modules/ecs-service"

  name               = "${local.name}-api"
  cluster_arn        = aws_ecs_cluster.this.arn
  cluster_name       = aws_ecs_cluster.this.name
  cpu                = var.api_cpu
  memory             = var.api_memory
  execution_role_arn = aws_iam_role.execution.arn
  task_role_arn      = aws_iam_role.api.arn
  subnet_ids         = local.net.private_subnet_ids
  security_group_ids = [local.sec.app_sg_id]
  target_group_arn   = module.alb.target_group_arn
  container_name     = "api"
  container_port     = local.api_port
  min_tasks          = var.api_min_tasks
  max_tasks          = var.api_max_tasks

  # IAM changes take a few seconds to reach every AWS service. Without this,
  # the first tasks of a new environment can start before the execution role
  # may read the secrets, and fail.
  depends_on = [aws_iam_role_policy.execution_secrets, aws_iam_role_policy_attachment.execution_managed]

  # Two containers from the same image. migrate runs first and exits; api only
  # starts if migrate succeeded. See ADR 0012.
  container_definitions = jsonencode([
    merge(local.base_container, {
      name             = "migrate"
      command          = ["migrate"]
      essential        = false
      logConfiguration = local.log_options.api
    }),
    merge(local.base_container, {
      name             = "api"
      command          = ["api"]
      portMappings     = [{ containerPort = local.api_port, protocol = "tcp" }]
      dependsOn        = [{ containerName = "migrate", condition = "SUCCESS" }]
      logConfiguration = local.log_options.api
      stopTimeout      = 30
    }),
  ])
}

# ---- job task definitions (started by EventBridge Scheduler in step 06) -------------

module "check_task" {
  source = "../../modules/ecs-task"

  depends_on = [aws_iam_role_policy.execution_secrets, aws_iam_role_policy_attachment.execution_managed]

  family             = "${local.name}-check"
  cpu                = var.job_cpu
  memory             = var.job_memory
  execution_role_arn = aws_iam_role.execution.arn
  task_role_arn      = aws_iam_role.jobs.arn
  container_definitions = jsonencode([
    merge(local.base_container, {
      name             = "app"
      command          = ["check"]
      logConfiguration = local.log_options.jobs
    }),
  ])
}

module "rollup_task" {
  source = "../../modules/ecs-task"

  depends_on = [aws_iam_role_policy.execution_secrets, aws_iam_role_policy_attachment.execution_managed]

  family             = "${local.name}-rollup"
  cpu                = var.job_cpu
  memory             = var.job_memory
  execution_role_arn = aws_iam_role.execution.arn
  task_role_arn      = aws_iam_role.jobs.arn
  container_definitions = jsonencode([
    merge(local.base_container, {
      name             = "app"
      command          = ["rollup"]
      logConfiguration = local.log_options.jobs
    }),
  ])
}
