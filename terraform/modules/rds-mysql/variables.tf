variable "name" {
  description = "Prefix for every resource name, for example uptime-dev."
  type        = string
}

variable "subnet_ids" {
  description = "Isolated subnets, one per zone."
  type        = list(string)
}

variable "security_group_id" {
  type = string
}

variable "engine_version" {
  description = "MySQL major version. 8.4 is the long-term release; 8.0 is in paid extended support since mid-2026."
  type        = string
  default     = "8.4"
}

variable "instance_class" {
  type    = string
  default = "db.t4g.micro"
}

variable "allocated_storage" {
  description = "GB of gp3 storage to start with."
  type        = number
  default     = 20
}

variable "max_allocated_storage" {
  description = "RDS grows the disk by itself up to this many GB when it fills up."
  type        = number
  default     = 100
}

variable "multi_az" {
  description = "Keep a standby copy in a second zone that takes over automatically."
  type        = bool
  default     = false
}

variable "backup_retention_days" {
  description = "Days of automatic backups (point-in-time restore). 1 to 35."
  type        = number
  default     = 1
}

variable "deletion_protection" {
  type    = bool
  default = false
}

variable "skip_final_snapshot" {
  description = "true in dev so destroy is quick; false in prod so destroy leaves a last backup."
  type        = bool
  default     = true
}

variable "db_name" {
  type    = string
  default = "uptime"
}

variable "username" {
  type    = string
  default = "uptime"
}

variable "password_version" {
  description = "Change this number to make Terraform generate and set a new password."
  type        = number
  default     = 1
}

variable "secret_recovery_days" {
  description = "Days a deleted secret can be restored. 0 deletes it at once (handy in dev, where names get reused)."
  type        = number
  default     = 7
}
