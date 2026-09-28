# An internal Application Load Balancer: it gets private IPs only. CloudFront
# reaches it through a VPC origin (step 05); nothing on the internet can.

variable "name" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "subnet_ids" {
  description = "Private subnets, one per zone."
  type        = list(string)
}

variable "security_group_id" {
  type = string
}

variable "listener_port" {
  type    = number
  default = 80
}

variable "target_port" {
  type    = number
  default = 8080
}

variable "health_check_path" {
  description = "Must not touch the database (see /api/health in step 01)."
  type        = string
  default     = "/api/health"
}

variable "deletion_protection" {
  type    = bool
  default = false
}

resource "aws_lb" "this" {
  name               = var.name
  internal           = true
  load_balancer_type = "application"
  subnets            = var.subnet_ids
  security_groups    = [var.security_group_id]

  drop_invalid_header_fields = true
  enable_deletion_protection = var.deletion_protection
  idle_timeout               = 60
}

resource "aws_lb_target_group" "api" {
  name        = "${var.name}-api"
  vpc_id      = var.vpc_id
  port        = var.target_port
  protocol    = "HTTP"
  target_type = "ip" # Fargate tasks register by IP

  # How long a task keeps getting in-flight requests after it is told to
  # stop. The API finishes requests within a few seconds.
  deregistration_delay = 30

  health_check {
    path                = var.health_check_path
    matcher             = "200"
    interval            = 15
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = var.listener_port
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.api.arn
  }
}

output "arn" {
  value = aws_lb.this.arn
}

output "arn_suffix" {
  description = "Used as the LoadBalancer dimension in CloudWatch metrics."
  value       = aws_lb.this.arn_suffix
}

output "dns_name" {
  value = aws_lb.this.dns_name
}

output "target_group_arn" {
  value = aws_lb_target_group.api.arn
}

output "target_group_arn_suffix" {
  value = aws_lb_target_group.api.arn_suffix
}
