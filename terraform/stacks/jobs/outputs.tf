output "schedule_group" {
  value = aws_scheduler_schedule_group.this.name
}

output "schedules" {
  value = { for k, s in aws_scheduler_schedule.job : k => s.schedule_expression }
}
