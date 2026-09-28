# A VPC with three kinds of subnets in each Availability Zone:
#
#   public    has a route to the internet gateway (load balancer, NAT gateway)
#   private   reaches the internet only through a NAT gateway (ECS tasks)
#   isolated  no route to the internet at all (RDS)
#
# Subnet numbers are fixed so addresses are easy to read:
#   10.x.0.0/24,  10.x.1.0/24   public
#   10.x.10.0/24, 10.x.11.0/24  private
#   10.x.20.0/24, 10.x.21.0/24  isolated

locals {
  tiers = {
    public   = 0
    private  = 10
    isolated = 20
  }

  # NAT gateway i lives in public subnet i. With "single" there is only
  # nat 0, and every zone's private route table points at it.
  nat_count = var.nat_gateway_mode == "per_az" ? length(var.azs) : (var.nat_gateway_mode == "single" ? 1 : 0)
}

resource "aws_vpc" "this" {
  cidr_block           = var.cidr
  enable_dns_support   = true
  enable_dns_hostnames = true # RDS and VPC endpoints need DNS names

  tags = { Name = var.name }
}

# The default security group allows all traffic between its members. Nothing
# should use it, so we take away all its rules.
resource "aws_default_security_group" "this" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "${var.name}-default-unused" }
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = var.name }
}

# ---- subnets ----------------------------------------------------------------

resource "aws_subnet" "public" {
  count = length(var.azs)

  vpc_id            = aws_vpc.this.id
  availability_zone = var.azs[count.index]
  cidr_block        = cidrsubnet(var.cidr, 8, local.tiers.public + count.index)

  # Nothing we run here needs its own public IP: the load balancer and the
  # NAT gateway get theirs explicitly.
  map_public_ip_on_launch = false

  tags = { Name = "${var.name}-public-${var.azs[count.index]}", Tier = "public" }
}

resource "aws_subnet" "private" {
  count = length(var.azs)

  vpc_id            = aws_vpc.this.id
  availability_zone = var.azs[count.index]
  cidr_block        = cidrsubnet(var.cidr, 8, local.tiers.private + count.index)

  tags = { Name = "${var.name}-private-${var.azs[count.index]}", Tier = "private" }
}

resource "aws_subnet" "isolated" {
  count = length(var.azs)

  vpc_id            = aws_vpc.this.id
  availability_zone = var.azs[count.index]
  cidr_block        = cidrsubnet(var.cidr, 8, local.tiers.isolated + count.index)

  tags = { Name = "${var.name}-isolated-${var.azs[count.index]}", Tier = "isolated" }
}

# ---- public routing: what makes a subnet "public" ---------------------------

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "${var.name}-public" }
}

resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id
}

resource "aws_route_table_association" "public" {
  count = length(var.azs)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# ---- NAT gateways -------------------------------------------------------------

resource "aws_eip" "nat" {
  count = local.nat_count

  domain = "vpc"
  tags   = { Name = "${var.name}-nat-${var.azs[count.index]}" }
}

resource "aws_nat_gateway" "this" {
  count = local.nat_count

  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = { Name = "${var.name}-${var.azs[count.index]}" }

  # A NAT gateway sends traffic out through the internet gateway.
  depends_on = [aws_internet_gateway.this]
}

# ---- private routing: one table per zone ------------------------------------
#
# One table per zone even with a single NAT gateway. Switching to per_az then
# only changes where each route points; no subnet moves to another table.

resource "aws_route_table" "private" {
  count = length(var.azs)

  vpc_id = aws_vpc.this.id
  tags   = { Name = "${var.name}-private-${var.azs[count.index]}" }
}

resource "aws_route" "private_nat" {
  count = local.nat_count > 0 ? length(var.azs) : 0

  route_table_id         = aws_route_table.private[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.this[min(count.index, local.nat_count - 1)].id
}

resource "aws_route_table_association" "private" {
  count = length(var.azs)

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

# ---- isolated routing: only the VPC itself ----------------------------------

resource "aws_route_table" "isolated" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "${var.name}-isolated" }
}

resource "aws_route_table_association" "isolated" {
  count = length(var.azs)

  subnet_id      = aws_subnet.isolated[count.index].id
  route_table_id = aws_route_table.isolated.id
}

# ---- S3 gateway endpoint ------------------------------------------------------
#
# Free. S3 traffic from private subnets goes straight to S3 instead of through
# the NAT gateway, which charges per GB. ECR stores image layers in S3, so every
# Fargate task start pulls its image this way.

data "aws_region" "current" {}

resource "aws_vpc_endpoint" "s3" {
  count = var.enable_s3_endpoint ? 1 : 0

  vpc_id            = aws_vpc.this.id
  service_name      = "com.amazonaws.${data.aws_region.current.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = aws_route_table.private[*].id

  tags = { Name = "${var.name}-s3" }
}
