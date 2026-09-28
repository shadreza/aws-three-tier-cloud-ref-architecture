terraform {
  required_version = ">= 1.11"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  # The bucket and key come from envs/<env>/backend.hcl and the Makefile, so
  # the same code can hold dev, staging and prod state side by side.
  backend "s3" {}
}
