# main.tf - Secrets Manager Module

# Creates the container for the secret
resource "aws_secretsmanager_secret" "db_master_password" {
  name        = "${var.name}-rds-master-password-v32"
  description = "RDS master password for the ${var.name}-database"

  tags = {
    Name = "${var.name}-rds-master-password-v32"
  }
}
# Stores the actual secret value
resource "aws_secretsmanager_secret_version" "db_master_password_version" {
  secret_id = aws_secretsmanager_secret.db_master_password.id

  secret_string = jsonencode({
    username = var.db_username
    password = var.db_password
  })
}
