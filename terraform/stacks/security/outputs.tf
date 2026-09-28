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
