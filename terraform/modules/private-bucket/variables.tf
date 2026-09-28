variable "name" {
  description = "The bucket name. Must be unique across all of AWS."
  type        = string
}

variable "force_destroy" {
  description = "Let terraform destroy delete the bucket even if it still has objects (dev only)."
  type        = bool
  default     = false
}

variable "expire_after_days" {
  description = "Delete objects this many days after they were written. 0 keeps them forever."
  type        = number
  default     = 0
}

variable "versioning" {
  type    = bool
  default = false
}

variable "extra_policy_json" {
  description = "More bucket policy statements, for example CloudFront read access (step 05)."
  type        = string
  default     = null
}
