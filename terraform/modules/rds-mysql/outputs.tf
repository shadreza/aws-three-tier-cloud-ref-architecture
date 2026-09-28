output "address" {
  description = "The DNS name to connect to. It stays the same during a Multi-AZ failover."
  value       = aws_db_instance.this.address
}

output "port" {
  value = aws_db_instance.this.port
}

output "db_name" {
  value = var.db_name
}

output "username" {
  value = var.username
}

output "secret_arn" {
  description = "ECS reads the password from this secret, key password."
  value       = aws_secretsmanager_secret.db.arn
}

output "identifier" {
  value = aws_db_instance.this.identifier
}
