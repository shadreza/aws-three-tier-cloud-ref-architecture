# One security group per role. Rules point at other security groups, not at
# IP ranges, so "the API may talk to the database" stays true however many
# tasks run and whatever IPs they get.
#
#   CloudFront (VPC origin) -> alb :80    (rule added by the edge stack, step 05)
#   alb                     -> app :8080
#   app, jobs               -> db  :3306
#   jobs                    -> internet (the websites we check)
#   app, jobs               -> AWS APIs on :443 (ECR, Secrets Manager, logs, S3)
#
# The load balancer is internal (private subnets, no public IP). CloudFront
# reaches it through a VPC origin; nothing on the internet can.
#
# DNS lookups to the VPC resolver are not filtered by security groups, so no
# rule is needed for them.

resource "aws_security_group" "alb" {
  name        = "${var.name}-alb"
  description = "Internal load balancer: HTTP in from CloudFront, out to the API tasks"
  vpc_id      = var.vpc_id
  tags        = { Name = "${var.name}-alb" }
}

resource "aws_security_group" "app" {
  name        = "${var.name}-app"
  description = "API tasks: in from the load balancer only"
  vpc_id      = var.vpc_id
  tags        = { Name = "${var.name}-app" }
}

resource "aws_security_group" "jobs" {
  name        = "${var.name}-jobs"
  description = "Scheduled check and rollup tasks: nothing comes in"
  vpc_id      = var.vpc_id
  tags        = { Name = "${var.name}-jobs" }
}

resource "aws_security_group" "db" {
  name        = "${var.name}-db"
  description = "RDS MySQL: in from the API and job tasks only"
  vpc_id      = var.vpc_id
  tags        = { Name = "${var.name}-db" }
}

# ---- alb ---------------------------------------------------------------------

resource "aws_vpc_security_group_ingress_rule" "alb_from_cidrs" {
  for_each = toset(var.alb_ingress_cidrs)

  security_group_id = aws_security_group.alb.id
  description       = "HTTP from an allowed range"
  cidr_ipv4         = each.value
  from_port         = var.alb_port
  to_port           = var.alb_port
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "alb_to_app" {
  security_group_id            = aws_security_group.alb.id
  description                  = "Forward requests and health checks to the API tasks"
  referenced_security_group_id = aws_security_group.app.id
  from_port                    = var.app_port
  to_port                      = var.app_port
  ip_protocol                  = "tcp"
}

# ---- app (API tasks) ------------------------------------------------------------

resource "aws_vpc_security_group_ingress_rule" "app_from_alb" {
  security_group_id            = aws_security_group.app.id
  description                  = "Requests from the load balancer"
  referenced_security_group_id = aws_security_group.alb.id
  from_port                    = var.app_port
  to_port                      = var.app_port
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "app_to_db" {
  security_group_id            = aws_security_group.app.id
  description                  = "MySQL"
  referenced_security_group_id = aws_security_group.db.id
  from_port                    = var.db_port
  to_port                      = var.db_port
  ip_protocol                  = "tcp"
}

# The API calls no websites, but the task still needs HTTPS to AWS APIs
# (image pull, secrets, logs, S3 reports) through the NAT or the S3 endpoint.
resource "aws_vpc_security_group_egress_rule" "app_to_https" {
  security_group_id = aws_security_group.app.id
  description       = "HTTPS to AWS APIs"
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
}

# ---- jobs (check, rollup) -------------------------------------------------------

resource "aws_vpc_security_group_egress_rule" "jobs_to_db" {
  security_group_id            = aws_security_group.jobs.id
  description                  = "MySQL"
  referenced_security_group_id = aws_security_group.db.id
  from_port                    = var.db_port
  to_port                      = var.db_port
  ip_protocol                  = "tcp"
}

# Monitors can use any port (https://example.com:8443), so the checker may
# connect to any TCP port on the internet. internal/netguard, not this rule,
# stops it from reaching private addresses.
resource "aws_vpc_security_group_egress_rule" "jobs_to_internet" {
  security_group_id = aws_security_group.jobs.id
  description       = "Checks to any website, plus HTTPS to AWS APIs"
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 1
  to_port           = 65535
  ip_protocol       = "tcp"
}

# ---- db ------------------------------------------------------------------------

resource "aws_vpc_security_group_ingress_rule" "db_from_app" {
  security_group_id            = aws_security_group.db.id
  description                  = "MySQL from the API tasks"
  referenced_security_group_id = aws_security_group.app.id
  from_port                    = var.db_port
  to_port                      = var.db_port
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "db_from_jobs" {
  security_group_id            = aws_security_group.db.id
  description                  = "MySQL from the job tasks"
  referenced_security_group_id = aws_security_group.jobs.id
  from_port                    = var.db_port
  to_port                      = var.db_port
  ip_protocol                  = "tcp"
}

# The db group has no egress rules. Security groups are stateful: replies to
# allowed connections go back out without a rule.
