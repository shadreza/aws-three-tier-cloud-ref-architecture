output "alb_sg_id" {
  value = module.security_groups.alb_sg_id
}

output "app_sg_id" {
  value = module.security_groups.app_sg_id
}

output "jobs_sg_id" {
  value = module.security_groups.jobs_sg_id
}

output "db_sg_id" {
  value = module.security_groups.db_sg_id
}

output "alb_port" {
  value = module.security_groups.alb_port
}

output "debug_host_instance_id" {
  description = "Connect with: aws ec2-instance-connect ssh --instance-id <id> --connection-type eice"
  value       = var.enable_debug_host ? module.debug_host[0].instance_id : null
}
