output "db_address" {
  value = module.db.address
}

output "db_port" {
  value = module.db.port
}

output "db_name" {
  value = module.db.db_name
}

output "db_username" {
  value = module.db.username
}

output "db_identifier" {
  value = module.db.identifier
}

output "db_secret_arn" {
  value = module.db.secret_arn
}

output "admin_token_secret_arn" {
  value = aws_secretsmanager_secret.admin_token.arn
}

output "reports_bucket" {
  value = module.reports.id
}

output "reports_bucket_arn" {
  value = module.reports.arn
}
