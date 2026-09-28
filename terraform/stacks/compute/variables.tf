variable "api_cpu" {
  description = "CPU units per API task (256 = 0.25 vCPU)."
  type        = number
}

variable "api_memory" {
  description = "MiB per API task."
  type        = number
}

variable "api_min_tasks" {
  description = "Tasks always running. 2 or more spreads them over both zones."
  type        = number
}

variable "api_max_tasks" {
  description = "Autoscaling may go up to this many. Equal to api_min_tasks turns autoscaling off."
  type        = number
}

variable "job_cpu" {
  type    = number
  default = 256
}

variable "job_memory" {
  type    = number
  default = 512
}

variable "log_retention_days" {
  type = number
}

variable "alb_deletion_protection" {
  type = bool
}

variable "check_timeout" {
  description = "How long one website check may take."
  type        = string
  default     = "10s"
}

variable "check_concurrency" {
  type    = number
  default = 10
}

variable "retention_days" {
  description = "Days of raw check results the rollup job keeps."
  type        = number
  default     = 30
}
