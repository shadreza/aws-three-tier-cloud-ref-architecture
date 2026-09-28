variable "schedules_enabled" {
  description = "false pauses both schedules (the tasks stop running, nothing is deleted)."
  type        = bool
  default     = true
}

variable "check_schedule" {
  description = "How often to check every monitor."
  type        = string
  default     = "rate(1 minute)"
}

variable "rollup_schedule" {
  description = "How often to rebuild today's and yesterday's summaries and report."
  type        = string
  default     = "rate(1 hour)"
}
