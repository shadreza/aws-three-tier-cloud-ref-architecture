variable "db_instance_class" {
  type = string
}

variable "db_multi_az" {
  type = bool
}

variable "db_backup_retention_days" {
  type = number
}

variable "db_deletion_protection" {
  type = bool
}

variable "db_skip_final_snapshot" {
  type = bool
}

variable "db_password_version" {
  description = "Bump to rotate the database password (then restart the ECS service)."
  type        = number
  default     = 1
}

variable "admin_token_version" {
  description = "Bump to generate a new admin token."
  type        = number
  default     = 1
}

variable "secret_recovery_days" {
  type = number
}

variable "reports_expire_days" {
  description = "Delete daily reports older than this."
  type        = number
}

variable "reports_force_destroy" {
  description = "Allow destroy to delete a bucket that still has reports in it."
  type        = bool
}
