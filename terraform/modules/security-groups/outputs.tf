output "alb_sg_id" {
  value = aws_security_group.alb.id
}

output "app_sg_id" {
  value = aws_security_group.app.id
}

output "jobs_sg_id" {
  value = aws_security_group.jobs.id
}

output "db_sg_id" {
  value = aws_security_group.db.id
}

output "alb_port" {
  value = var.alb_port
}
