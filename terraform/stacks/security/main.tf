# Reads the network stack's outputs from its state file.
data "terraform_remote_state" "network" {
  backend = "s3"
  config = {
    bucket = local.state_bucket
    key    = "${var.environment}/network.tfstate"
    region = var.region
  }
}

module "security_groups" {
  source = "../../modules/security-groups"

  name              = local.name
  vpc_id            = data.terraform_remote_state.network.outputs.vpc_id
  alb_ingress_cidrs = var.alb_ingress_cidrs
}
