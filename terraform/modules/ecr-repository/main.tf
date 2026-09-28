variable "name" {
  description = "Repository name, for example uptime-dev/backend."
  type        = string
}

variable "keep_images" {
  description = "How many images to keep. Older ones are deleted, so you cannot roll back further than this."
  type        = number
  default     = 50
}

variable "force_delete" {
  description = "Let terraform destroy delete the repository even if it still has images (dev only)."
  type        = bool
  default     = false
}

# Tags cannot be overwritten: "abc123" always means the same image, so a
# deploy or a rollback to that tag is exactly what was tested.
resource "aws_ecr_repository" "this" {
  name                 = var.name
  image_tag_mutability = "IMMUTABLE"
  force_delete         = var.force_delete

  # Free basic scan for known vulnerabilities in OS packages on every push.
  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_lifecycle_policy" "this" {
  repository = aws_ecr_repository.this.name
  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Delete untagged images after a day"
        selection    = { tagStatus = "untagged", countType = "sinceImagePushed", countUnit = "days", countNumber = 1 }
        action       = { type = "expire" }
      },
      {
        rulePriority = 2
        description  = "Keep the newest ${var.keep_images} images"
        selection    = { tagStatus = "any", countType = "imageCountMoreThan", countNumber = var.keep_images }
        action       = { type = "expire" }
      },
    ]
  })
}

output "url" {
  value = aws_ecr_repository.this.repository_url
}

output "arn" {
  value = aws_ecr_repository.this.arn
}

output "name" {
  value = aws_ecr_repository.this.name
}
