data "terraform_remote_state" "network" {
  backend = "s3"
  config = {
    bucket = local.state_bucket
    key    = "${var.environment}/network.tfstate"
    region = var.region
  }
}

data "terraform_remote_state" "security" {
  backend = "s3"
  config = {
    bucket = local.state_bucket
    key    = "${var.environment}/security.tfstate"
    region = var.region
  }
}

module "db" {
  source = "../../modules/rds-mysql"

  name                  = local.name
  subnet_ids            = data.terraform_remote_state.network.outputs.isolated_subnet_ids
  security_group_id     = data.terraform_remote_state.security.outputs.db_sg_id
  instance_class        = var.db_instance_class
  multi_az              = var.db_multi_az
  backup_retention_days = var.db_backup_retention_days
  deletion_protection   = var.db_deletion_protection
  skip_final_snapshot   = var.db_skip_final_snapshot
  password_version      = var.db_password_version
  secret_recovery_days  = var.secret_recovery_days
}

# The token that lets someone add or delete monitors (ADMIN_TOKEN). Generated
# here and written straight into Secrets Manager; it never touches the state.
ephemeral "random_password" "admin_token" {
  length  = 40
  special = false
}

resource "aws_secretsmanager_secret" "admin_token" {
  name                    = "${local.name}/admin-token"
  description             = "ADMIN_TOKEN for the Uptime API in ${local.name}."
  recovery_window_in_days = var.secret_recovery_days
}

resource "aws_secretsmanager_secret_version" "admin_token" {
  secret_id                = aws_secretsmanager_secret.admin_token.id
  secret_string_wo         = ephemeral.random_password.admin_token.result
  secret_string_wo_version = var.admin_token_version
}

module "reports" {
  source = "../../modules/private-bucket"

  name              = "${local.name}-reports-${var.account_id}"
  expire_after_days = var.reports_expire_days
  force_destroy     = var.reports_force_destroy
}
