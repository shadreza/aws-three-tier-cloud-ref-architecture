# A long-running Fargate service behind a load balancer target group, with
# rolling deploys that roll back by themselves when the new tasks do not get
# healthy, and optional CPU-based autoscaling.

variable "name" {
  type = string
}

variable "cluster_arn" {
  type = string
}

variable "cluster_name" {
  type = string
}

variable "cpu" {
  type = number
}

variable "memory" {
  type = number
}

variable "execution_role_arn" {
  type = string
}

variable "task_role_arn" {
  type = string
}

variable "container_definitions" {
  type = string
}

variable "subnet_ids" {
  type = list(string)
}

variable "security_group_ids" {
  type = list(string)
}

variable "target_group_arn" {
  type = string
}

variable "container_name" {
  description = "The container the load balancer sends traffic to."
  type        = string
}

variable "container_port" {
  type = number
}

variable "min_tasks" {
  type = number
}

variable "max_tasks" {
  type = number
}

variable "cpu_target_percent" {
  description = "Add tasks when average CPU goes above this."
  type        = number
  default     = 60
}

module "task" {
  source = "../ecs-task"

  family                = var.name
  cpu                   = var.cpu
  memory                = var.memory
  execution_role_arn    = var.execution_role_arn
  task_role_arn         = var.task_role_arn
  container_definitions = var.container_definitions
}

resource "aws_ecs_service" "this" {
  name            = var.name
  cluster         = var.cluster_arn
  task_definition = module.task.arn
  desired_count   = var.min_tasks
  launch_type     = "FARGATE"

  # Spread tasks across zones again after a zone comes back.
  availability_zone_rebalancing = "ENABLED"

  network_configuration {
    subnets          = var.subnet_ids
    security_groups  = var.security_group_ids
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = var.target_group_arn
    container_name   = var.container_name
    container_port   = var.container_port
  }

  # Start new tasks before stopping old ones, so a deploy never drops below
  # the current capacity.
  deployment_minimum_healthy_percent = 100
  deployment_maximum_percent         = 200

  # If new tasks keep failing, stop the deploy and go back to the last one
  # that worked.
  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  # Give the migrate container and the API time to start before the load
  # balancer's health checks count.
  health_check_grace_period_seconds = 60

  propagate_tags = "SERVICE"

  lifecycle {
    # Autoscaling changes the number of tasks; Terraform should not undo that.
    ignore_changes = [desired_count]
  }
}

resource "aws_appautoscaling_target" "this" {
  count = var.max_tasks > var.min_tasks ? 1 : 0

  service_namespace  = "ecs"
  resource_id        = "service/${var.cluster_name}/${aws_ecs_service.this.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  min_capacity       = var.min_tasks
  max_capacity       = var.max_tasks
}

resource "aws_appautoscaling_policy" "cpu" {
  count = var.max_tasks > var.min_tasks ? 1 : 0

  name               = "${var.name}-cpu"
  policy_type        = "TargetTrackingScaling"
  service_namespace  = aws_appautoscaling_target.this[0].service_namespace
  resource_id        = aws_appautoscaling_target.this[0].resource_id
  scalable_dimension = aws_appautoscaling_target.this[0].scalable_dimension

  target_tracking_scaling_policy_configuration {
    target_value       = var.cpu_target_percent
    scale_in_cooldown  = 300
    scale_out_cooldown = 60
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
  }
}

output "name" {
  value = aws_ecs_service.this.name
}

output "task_definition_arn" {
  value = module.task.arn
}
