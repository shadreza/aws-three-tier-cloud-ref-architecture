# A Fargate task definition on ARM (Graviton), for tasks that run and stop:
# check and rollup. Something else starts them (EventBridge Scheduler, step 06,
# or you with aws ecs run-task).

variable "family" {
  type = string
}

variable "cpu" {
  description = "CPU units: 256 = 0.25 vCPU."
  type        = number
}

variable "memory" {
  description = "MiB. Must fit the CPU size (256 CPU: 512 to 2048)."
  type        = number
}

variable "execution_role_arn" {
  description = "Used by ECS itself: pull the image, read secrets, write logs."
  type        = string
}

variable "task_role_arn" {
  description = "Used by the app inside the container, for example to write to S3."
  type        = string
}

variable "container_definitions" {
  description = "JSON list of containers."
  type        = string
}

resource "aws_ecs_task_definition" "this" {
  family                   = var.family
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.cpu
  memory                   = var.memory
  execution_role_arn       = var.execution_role_arn
  task_role_arn            = var.task_role_arn
  container_definitions    = var.container_definitions

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "ARM64" # about 20% cheaper than X86_64
  }
}

output "arn" {
  value = aws_ecs_task_definition.this.arn
}

output "arn_without_revision" {
  value = aws_ecs_task_definition.this.arn_without_revision
}

output "family" {
  value = aws_ecs_task_definition.this.family
}
