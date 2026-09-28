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

module "debug_host" {
  source = "../../modules/debug-host"
  count  = var.enable_debug_host ? 1 : 0

  name      = local.name
  vpc_id    = data.terraform_remote_state.network.outputs.vpc_id
  subnet_id = data.terraform_remote_state.network.outputs.private_subnet_ids[0]
}

# The debug host may reach the database, like the app does.
resource "aws_vpc_security_group_ingress_rule" "db_from_debug" {
  count = var.enable_debug_host ? 1 : 0

  security_group_id            = module.security_groups.db_sg_id
  description                  = "MySQL from the debug host"
  referenced_security_group_id = module.debug_host[0].security_group_id
  from_port                    = 3306
  to_port                      = 3306
  ip_protocol                  = "tcp"
}

# ...and the internal load balancer, to test the API before CloudFront exists.
resource "aws_vpc_security_group_ingress_rule" "alb_from_debug" {
  count = var.enable_debug_host ? 1 : 0

  security_group_id            = module.security_groups.alb_sg_id
  description                  = "HTTP from the debug host"
  referenced_security_group_id = module.debug_host[0].security_group_id
  from_port                    = module.security_groups.alb_port
  to_port                      = module.security_groups.alb_port
  ip_protocol                  = "tcp"
}
