# main.tf - RDS module

resource "aws_db_subnet_group" "main" {
  name        = "${var.project_name}-${var.env}-rds-subnet-group"
  subnet_ids  = var.private_db_subnet_ids
  description = "Subnet group for ${var.project_name}-${var.env} RDS instance"

  tags = {
    Name        = "${var.project_name}-${var.env}-rds-subnet-group"
    Project     = var.project_name
    Environment = var.env
  }
}

resource "aws_security_group" "db_sg" {
  name        = "${var.project_name}-${var.env}-rds-sg"
  description = "Allow inbound traffic to RDS instance"
  vpc_id      = var.vpc_id

  # Ingress rules will be added from the backend ECS security group later in the root module
  # to prevent circular dependencies. This SG primarily defines the databases's network boundary.

  tags = {
    Name        = "${var.project_name}-${var.env}-rds-sg"
    Project     = var.project_name
    Environment = var.env
  }
}

resource "aws_db_instance" "main" {
  identifier              = "${var.project_name}-${var.env}-db"
  engine                  = "postgres"
  engine_version          = "15.4"
  instance_class          = var.db_instance_type
  allocated_storage       = var.db_allocated_storage
  db_name                 = var.db_name
  username                = var.db_username
  password                = data.aws_secretsmanager_secret_version.db_master_password.secret_string # Use data source to retrieve secret
  db_subnet_group_name    = aws_db_subnet_group.main.name
  vpc_security_group_ids  = [aws_security_group.db_sg.id]
  skip_final_snapshot     = true          # Set to false for production!
  backup_retention_period = 7             # Days to retain automated backups
  backup_window           = "03:00-05:00" # UTC time
  storage_encrypted       = true          # Ensure encryption at rest
  kms_key_id              = ""            # Leave blank for AWS-managed key, or provide your KMS key ARN
  apply_immediately       = true          # Apply changes immediately, useful for dev, use false for prod to schedule maintenance window
  # Other recommended settings for production:
  # deletions_protection = true
  # final_snapshot_identifier = "${var.project_name}-${var.env}-final-snapshot" # Required if skip_final_snapshot is false

  tags = {
    Name        = "${var.project_name}-${var.env}-db"
    Project     = var.project_name
    Environment = var.env
    Type        = "PostgreSQL"
  }
}

# Data source to retrieve the actual secret string from Secrets Manager
data "aws_secretsmanager_secret_version" "db_master_password" {
  secret_id = var.secrets_manager_db_secret_arn
}
