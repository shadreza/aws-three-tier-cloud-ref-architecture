module "network" {
  source = "../../modules/network"

  name             = local.name
  cidr             = var.vpc_cidr
  azs              = var.azs
  nat_gateway_mode = var.nat_gateway_mode
}
