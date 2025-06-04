# main.tf - Secrets Manager Module

# Creates the container for the secret
resource "aws_secretsmanager_secret" "db_master_password" {
  name        = "${var.project_name}-${var.env}-rds-master-password"
  description = "RDS master password for the ${var.project_name}-${var.env} database"

  tags = {
    Name        = "${var.project_name}-${var.env}-rds-master-password"
    Project     = var.project_name
    Environment = var.env
  }
}
# Stores the actual secret value
resource "aws_secretsmanager_secret_version" "db_master_password_version" {
  secret_id = aws_secretsmanager_secret.db_master_password.id

  secret_string = jsonencode({
    username = var.db_username
    password = random_password.db_master_password.result
  })
}
