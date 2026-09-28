data "terraform_remote_state" "data" {
  backend = "s3"
  config = {
    bucket = local.state_bucket
    key    = "${var.environment}/data.tfstate"
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

data "terraform_remote_state" "jobs" {
  backend = "s3"
  config = {
    bucket = local.state_bucket
    key    = "${var.environment}/jobs.tfstate"
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

locals {
  db      = data.terraform_remote_state.data.outputs
  compute = data.terraform_remote_state.compute.outputs
  jobs    = data.terraform_remote_state.jobs.outputs
  edge    = data.terraform_remote_state.edge.outputs

  # Our own metrics, made from log lines, live in this namespace.
  namespace = "Uptime/${var.environment}"

  alb_dims = tomap({ LoadBalancer = local.compute.alb_arn_suffix })
  tg_dims  = tomap({ LoadBalancer = local.compute.alb_arn_suffix, TargetGroup = local.compute.target_group_arn_suffix })
  db_dims  = tomap({ DBInstanceIdentifier = local.db.db_identifier })
  no_dims  = tomap({})
}

# ---- where alerts go ----------------------------------------------------------------

resource "aws_sns_topic" "alerts" {
  name = "${local.name}-alerts"
}

resource "aws_sns_topic_subscription" "email" {
  count = var.alert_email == "" ? 0 : 1

  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# ---- metrics from log lines -----------------------------------------------------------
#
# The app writes JSON logs, so CloudWatch can match fields, not just text.

# One per check run that finished (or found nothing to check). If this stops,
# the whole chain is broken somewhere: scheduler, ECS, network, database.
resource "aws_cloudwatch_log_metric_filter" "check_runs" {
  name           = "check-runs"
  log_group_name = local.compute.jobs_log_group
  pattern        = "{ $.msg = \"check finished\" || $.msg = \"no monitors to check\" }"

  metric_transformation {
    name          = "CheckRuns"
    namespace     = local.namespace
    value         = "1"
    default_value = "0"
  }
}

# How many monitored websites were down in each check. This is the product
# itself: it goes on the dashboard.
resource "aws_cloudwatch_log_metric_filter" "monitors_down" {
  name           = "monitors-down"
  log_group_name = local.compute.jobs_log_group
  pattern        = "{ $.msg = \"check finished\" }"

  metric_transformation {
    name      = "MonitorsDown"
    namespace = local.namespace
    value     = "$.down"
  }
}

resource "aws_cloudwatch_log_metric_filter" "errors" {
  for_each = {
    api  = local.compute.api_log_group
    jobs = local.compute.jobs_log_group
  }

  name           = "errors-${each.key}"
  log_group_name = each.value
  pattern        = "{ $.level = \"ERROR\" }"

  metric_transformation {
    name          = "Errors"
    namespace     = local.namespace
    value         = "1"
    default_value = "0"
  }
}

# ---- alarms -----------------------------------------------------------------------------

locals {
  alarms = {
    # Users see errors
    "api-5xx" = {
      description = "The API answered with 5xx errors."
      namespace   = "AWS/ApplicationELB", metric = "HTTPCode_Target_5XX_Count", stat = "Sum"
      dims        = local.alb_dims, period = 300, periods = 1, op = "GreaterThanThreshold", threshold = 5
      missing     = "notBreaching"
    }
    "alb-5xx" = {
      description = "The load balancer itself answered 5xx: usually no healthy task, or a task timing out."
      namespace   = "AWS/ApplicationELB", metric = "HTTPCode_ELB_5XX_Count", stat = "Sum"
      dims        = local.alb_dims, period = 300, periods = 1, op = "GreaterThanThreshold", threshold = 5
      missing     = "notBreaching"
    }
    "api-no-healthy-tasks" = {
      description = "No API task passes its health check. The app is down."
      namespace   = "AWS/ApplicationELB", metric = "HealthyHostCount", stat = "Minimum"
      dims        = local.tg_dims, period = 60, periods = 3, op = "LessThanThreshold", threshold = 1
      missing     = "breaching"
    }

    # Users see slowness
    "api-slow" = {
      description = "95% of API requests took longer than ${var.api_p95_latency_seconds} s."
      namespace   = "AWS/ApplicationELB", metric = "TargetResponseTime", stat = "p95"
      dims        = local.alb_dims, period = 300, periods = 2, op = "GreaterThanThreshold", threshold = var.api_p95_latency_seconds
      missing     = "notBreaching"
    }

    # The database is in trouble
    "db-cpu-high" = {
      description = "Database CPU above 80% for 15 minutes."
      namespace   = "AWS/RDS", metric = "CPUUtilization", stat = "Average"
      dims        = local.db_dims, period = 300, periods = 3, op = "GreaterThanThreshold", threshold = 80
      missing     = "missing"
    }
    "db-cpu-credits-low" = {
      description = "t4g burst credits almost gone: the database will soon be slowed down."
      namespace   = "AWS/RDS", metric = "CPUCreditBalance", stat = "Minimum"
      dims        = local.db_dims, period = 300, periods = 3, op = "LessThanThreshold", threshold = 20
      missing     = "missing"
    }
    "db-storage-low" = {
      description = "Less than ${var.db_min_free_storage_gb} GB free on the database disk."
      namespace   = "AWS/RDS", metric = "FreeStorageSpace", stat = "Minimum"
      dims        = local.db_dims, period = 300, periods = 1, op = "LessThanThreshold", threshold = var.db_min_free_storage_gb * 1024 * 1024 * 1024
      missing     = "missing"
    }

    # The jobs stopped
    "scheduler-errors" = {
      description = "EventBridge Scheduler could not start a job task (permissions, bad task definition, capacity)."
      namespace   = "AWS/Scheduler", metric = "TargetErrorCount", stat = "Sum"
      dims        = tomap({ ScheduleGroup = local.jobs.schedule_group }), period = 300, periods = 1, op = "GreaterThanThreshold", threshold = 0
      missing     = "notBreaching"
    }
    "checks-stopped" = {
      description = "No check run finished in 10 minutes. Something between the scheduler and the database is broken."
      namespace   = local.namespace, metric = "CheckRuns", stat = "Sum"
      dims        = local.no_dims, period = 600, periods = 1, op = "LessThanThreshold", threshold = 1
      missing     = "breaching"
    }
    "app-errors" = {
      description = "The app logged more than 5 errors in 5 minutes."
      namespace   = local.namespace, metric = "Errors", stat = "Sum"
      dims        = local.no_dims, period = 300, periods = 1, op = "GreaterThanThreshold", threshold = 5
      missing     = "notBreaching"
    }
  }
}

resource "aws_cloudwatch_metric_alarm" "this" {
  for_each = local.alarms

  alarm_name        = "${local.name}-${each.key}"
  alarm_description = each.value.description
  namespace         = each.value.namespace
  metric_name       = each.value.metric
  dimensions        = each.value.dims

  statistic          = startswith(each.value.stat, "p") ? null : each.value.stat
  extended_statistic = startswith(each.value.stat, "p") ? each.value.stat : null

  period              = each.value.period
  evaluation_periods  = each.value.periods
  comparison_operator = each.value.op
  threshold           = each.value.threshold
  treat_missing_data  = each.value.missing

  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]

  depends_on = [aws_cloudwatch_log_metric_filter.check_runs, aws_cloudwatch_log_metric_filter.errors]
}

# ---- saved Logs Insights queries ------------------------------------------------------------

resource "aws_cloudwatch_query_definition" "slow_requests" {
  name            = "${local.name}/slowest-api-requests"
  log_group_names = [local.compute.api_log_group]
  query_string    = <<-EOT
    fields @timestamp, method, path, status, duration_ms
    | filter msg = "request"
    | sort duration_ms desc
    | limit 20
  EOT
}

resource "aws_cloudwatch_query_definition" "errors" {
  name            = "${local.name}/errors"
  log_group_names = [local.compute.api_log_group, local.compute.jobs_log_group]
  query_string    = <<-EOT
    fields @timestamp, @logStream, msg, error
    | filter level = "ERROR" or level = "WARN"
    | sort @timestamp desc
    | limit 50
  EOT
}

resource "aws_cloudwatch_query_definition" "check_runs" {
  name            = "${local.name}/check-runs"
  log_group_names = [local.compute.jobs_log_group]
  query_string    = <<-EOT
    fields @timestamp, monitors, up, down
    | filter msg = "check finished"
    | stats count(*) as runs, avg(down) as avg_down, max(down) as max_down by bin(1h)
  EOT
}

# ---- one dashboard ---------------------------------------------------------------------------

locals {
  widgets = [
    { title = "API requests and errors", metrics = [
      ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", local.compute.alb_arn_suffix, { stat = "Sum" }],
      [".", "HTTPCode_Target_5XX_Count", ".", ".", { stat = "Sum" }],
      [".", "HTTPCode_ELB_5XX_Count", ".", ".", { stat = "Sum" }],
    ] },
    { title = "API response time (p50, p95)", metrics = [
      ["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", local.compute.alb_arn_suffix, { stat = "p50" }],
      ["...", { stat = "p95" }],
    ] },
    { title = "API tasks: CPU and memory %", metrics = [
      ["AWS/ECS", "CPUUtilization", "ClusterName", local.compute.cluster_name, "ServiceName", local.compute.api_service_name],
      [".", "MemoryUtilization", ".", ".", ".", "."],
    ] },
    { title = "Healthy API tasks", metrics = [
      ["AWS/ApplicationELB", "HealthyHostCount", "TargetGroup", local.compute.target_group_arn_suffix, "LoadBalancer", local.compute.alb_arn_suffix, { stat = "Minimum" }],
    ] },
    { title = "Check runs and websites down", metrics = [
      [local.namespace, "CheckRuns", { stat = "Sum" }],
      [".", "MonitorsDown", { stat = "Maximum" }],
    ] },
    { title = "Scheduler", metrics = [
      ["AWS/Scheduler", "InvocationAttemptCount", "ScheduleGroup", local.jobs.schedule_group, { stat = "Sum" }],
      [".", "TargetErrorCount", ".", ".", { stat = "Sum" }],
    ] },
    { title = "Database CPU % and connections", metrics = [
      ["AWS/RDS", "CPUUtilization", "DBInstanceIdentifier", local.db.db_identifier],
      [".", "DatabaseConnections", ".", ".", { yAxis = "right" }],
    ] },
    { title = "Database free storage (bytes) and CPU credits", metrics = [
      ["AWS/RDS", "FreeStorageSpace", "DBInstanceIdentifier", local.db.db_identifier],
      [".", "CPUCreditBalance", ".", ".", { yAxis = "right" }],
    ] },
    { title = "WAF: allowed and blocked (us-east-1)", region = "us-east-1", metrics = [
      ["AWS/WAFV2", "AllowedRequests", "WebACL", local.edge.web_acl_name, "Rule", "ALL", { stat = "Sum" }],
      [".", "BlockedRequests", ".", ".", ".", ".", { stat = "Sum" }],
    ] },
  ]
}

resource "aws_cloudwatch_dashboard" "this" {
  dashboard_name = local.name
  dashboard_body = jsonencode({
    widgets = [
      for i, w in local.widgets : {
        type   = "metric"
        width  = 8
        height = 6
        x      = (i % 3) * 8
        y      = floor(i / 3) * 6
        properties = {
          title   = w.title
          region  = lookup(w, "region", var.region)
          metrics = w.metrics
          view    = "timeSeries"
          stacked = false
          period  = 300
        }
      }
    ]
  })
}
