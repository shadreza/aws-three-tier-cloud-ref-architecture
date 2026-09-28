# The container registry lives in its own stack because the image has to be
# pushed before the compute stack can start any task that uses it.

variable "ecr_force_delete" {
  description = "Allow destroy to delete the repository with images still in it."
  type        = bool
}

module "backend" {
  source = "../../modules/ecr-repository"

  name         = "${local.name}/backend"
  force_delete = var.ecr_force_delete
}

output "backend_repository_url" {
  value = module.backend.url
}

output "backend_repository_arn" {
  value = module.backend.arn
}

output "backend_repository_name" {
  value = module.backend.name
}
