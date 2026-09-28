variable "alert_email" {
  description = "Where alarms are sent. AWS emails a confirmation link first. Empty: no subscription."
  type        = string
  default     = ""
}

variable "api_p95_latency_seconds" {
  description = "Alarm when 95% of API requests are not faster than this."
  type        = number
  default     = 1
}

variable "db_min_free_storage_gb" {
  type    = number
  default = 2
}
