# A tiny machine inside the VPC for looking around: connect to RDS with the
# mysql client, curl things, check DNS. Nothing in the app needs it, so it is
# off by default (enable_debug_host) and costs about $0.005 an hour when on.
#
# You reach it through an EC2 Instance Connect Endpoint: no public IP, no SSH
# key to manage, no port open to the internet.

data "aws_ssm_parameter" "al2023_arm" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-arm64"
}

resource "aws_security_group" "eice" {
  name        = "${var.name}-eice"
  description = "Instance Connect Endpoint: SSH out to the debug host only"
  vpc_id      = var.vpc_id
  tags        = { Name = "${var.name}-eice" }
}

resource "aws_security_group" "host" {
  name        = "${var.name}-debug-host"
  description = "Debug host: SSH in from the Instance Connect Endpoint"
  vpc_id      = var.vpc_id
  tags        = { Name = "${var.name}-debug-host" }
}

resource "aws_vpc_security_group_egress_rule" "eice_to_host" {
  security_group_id            = aws_security_group.eice.id
  referenced_security_group_id = aws_security_group.host.id
  from_port                    = 22
  to_port                      = 22
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "host_from_eice" {
  security_group_id            = aws_security_group.host.id
  referenced_security_group_id = aws_security_group.eice.id
  from_port                    = 22
  to_port                      = 22
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "host_out" {
  security_group_id = aws_security_group.host.id
  description       = "Anything: it is a tool for poking around"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

resource "aws_ec2_instance_connect_endpoint" "this" {
  subnet_id          = var.subnet_id
  security_group_ids = [aws_security_group.eice.id]
  preserve_client_ip = false
  tags               = { Name = var.name }
}

resource "aws_instance" "this" {
  ami                         = data.aws_ssm_parameter.al2023_arm.value
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = [aws_security_group.host.id]
  associate_public_ip_address = false

  # IMDSv2 only: a stolen request from inside cannot read the metadata.
  metadata_options {
    http_tokens = "required"
  }

  # The MySQL client and the RDS certificate bundle, ready to use.
  user_data = <<-EOT
    #!/bin/bash
    dnf install -y mariadb105 jq
    curl -sfo /home/ec2-user/rds-ca.pem https://truststore.pki.rds.amazonaws.com/global/global-bundle.pem
    chown ec2-user /home/ec2-user/rds-ca.pem
  EOT

  tags = { Name = "${var.name}-debug" }

  lifecycle {
    ignore_changes = [ami] # a newer AMI is not a reason to replace the host
  }
}
