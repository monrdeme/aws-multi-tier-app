# main.tf - RDS module

resource "aws_db_subnet_group" "main" {
  name        = "${var.name}-rds-subnet-group"
  subnet_ids  = var.private_db_subnet_ids
  description = "Subnet group for ${var.name}-RDS instance"

  tags = {
    Name = "${var.name}-rds-subnet-group"
  }
}

resource "aws_security_group" "db_sg" {
  name        = "${var.name}-rds-sg"
  description = "Allow inbound traffic to RDS instance"
  vpc_id      = var.vpc_id

  # Ingress rules will be added from the backend ECS security group later in the root module
  # to prevent circular dependencies. This SG primarily defines the databases's network boundary.

  tags = {
    Name = "${var.name}-rds-sg"
  }
}

resource "aws_db_instance" "main" {
  identifier        = "${var.name}-db"
  engine            = "postgres"
  engine_version    = "15.7"
  instance_class    = var.db_instance_type
  allocated_storage = var.db_allocated_storage
  db_name           = var.db_name

  username = jsondecode(data.aws_secretsmanager_secret_version.db_master_password.secret_string)["username"]
  password = jsondecode(data.aws_secretsmanager_secret_version.db_master_password.secret_string)["password"] # Use data source to retrieve secret

  db_subnet_group_name    = aws_db_subnet_group.main.name
  vpc_security_group_ids  = [aws_security_group.db_sg.id]
  skip_final_snapshot     = true          # Set to false for production
  backup_retention_period = 7             # Days to retain automated backups
  backup_window           = "03:00-05:00" # UTC time
  storage_encrypted       = true          # Ensure encryption at rest
  apply_immediately       = true          # Apply changes immediately, useful for dev, use false for prod to schedule maintenance window
  # Other recommended settings for production:
  # deletions_protection = true
  # final_snapshot_identifier = "${var.name}-final-snapshot" # Required if skip_final_snapshot is false

  tags = {
    Name = "${var.name}-db"
    Type = "PostgresSQL"
  }
}

# Data source to retrieve the actual secret string from Secrets Manager
data "aws_secretsmanager_secret_version" "db_master_password" {
  secret_id = var.secrets_manager_db_secret_arn
}
