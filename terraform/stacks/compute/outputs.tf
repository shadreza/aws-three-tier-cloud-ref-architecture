output "cluster_name" {
  value = aws_ecs_cluster.this.name
}

output "cluster_arn" {
  value = aws_ecs_cluster.this.arn
}

output "api_service_name" {
  value = module.api.name
}

output "alb_arn" {
  value = module.alb.arn
}

output "alb_arn_suffix" {
  value = module.alb.arn_suffix
}

output "alb_dns_name" {
  description = "Internal: only reachable from inside the VPC (debug host) or by CloudFront."
  value       = module.alb.dns_name
}

output "target_group_arn_suffix" {
  value = module.alb.target_group_arn_suffix
}

output "image" {
  value = local.image
}

output "execution_role_arn" {
  value = aws_iam_role.execution.arn
}

output "jobs_task_role_arn" {
  value = aws_iam_role.jobs.arn
}

output "check_task_definition_arn" {
  value = module.check_task.arn
}

output "rollup_task_definition_arn" {
  value = module.rollup_task.arn
}

output "check_task_family" {
  value = module.check_task.family
}

output "rollup_task_family" {
  value = module.rollup_task.family
}

output "api_log_group" {
  value = aws_cloudwatch_log_group.api.name
}

output "jobs_log_group" {
  value = aws_cloudwatch_log_group.jobs.name
}

output "run_task_network" {
  description = "Paste into aws ecs run-task --network-configuration to start a one-off job."
  value       = "awsvpcConfiguration={subnets=[${join(",", local.net.private_subnet_ids)}],securityGroups=[${local.sec.jobs_sg_id}],assignPublicIp=DISABLED}"
}

# Without the revision number, RunTask always uses the newest revision, so
# the schedules do not need to change on every deploy.
output "check_task_definition_arn_latest" {
  value = module.check_task.arn_without_revision
}

output "rollup_task_definition_arn_latest" {
  value = module.rollup_task.arn_without_revision
}
