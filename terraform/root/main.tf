# main.tf - Root module

provider "aws" {
  region = var.aws_region
}

# Backend for Terraform state (S3 bucket and DynamoDB table for locking)
# IMPORTANT: You MUST create this S3 bucket and DynamoDB table manually ONCE before running terraform init for the first time.
# Replace <YOUR_ACCOUNT_ID> and <YOUR_BUCKET_NAME> with your actual values.
# The bucket must be in the specified region.
terraform {
  backend "s3" {
    bucket         = "tf-state-aws-multi-tier-app" # UNIQUE BUCKET NAME
    key            = "root/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "tf-state-locks-aws-multi-tier-app" # Name of your DynamoDB table for locking
  }
}

# --- Module Calls ---

# 1. VPC and Networking
module "vpc" {
  source                   = "../modules/vpc"
  name                     = var.name
  vpc_cidr                 = var.vpc_cidr
  public_subnet_cidrs      = var.public_subnet_cidrs
  private_app_subnet_cidrs = var.private_app_subnet_cidrs
  private_db_subnet_cidrs  = var.private_db_subnet_cidrs
  aws_region               = var.aws_region # Pass region for NAT Gateway EIP
}

# 2. CloudWatch Log Groups
module "cloudwatch_logs" {
  source = "../modules/cloudwatch-logs"
  name   = var.name
}

# 3. Secrets Manager (for RDS DB credentials)
module "secrets_manager" {
  source      = "../modules/secrets-manager"
  name        = var.name
  db_username = var.db_username
  db_password = random_password.db_master_password.result # Uses random_password for initial creation
}

# Resource to generate a strong random password for RDS master user
resource "random_password" "db_master_password" {
  length           = 16
  special          = true
  override_special = "!#$%^&*"
  min_upper        = 1
  min_lower        = 1
  min_numeric      = 1
  min_special      = 1
}

# 4. RDS Database
module "rds" {
  source                        = "../modules/rds"
  name                          = var.name
  vpc_id                        = module.vpc.vpc_id
  private_db_subnet_ids         = module.vpc.private_db_subnet_ids
  db_username                   = var.db_username
  secrets_manager_db_secret_arn = module.secrets_manager.db_secret_arn # Pass the ARN from Secrets Manager
  db_name                       = var.db_name
  db_instance_type              = var.db_instance_type
  db_allocated_storage          = var.db_allocated_storage
}
# Reference the security group for RDS, created in the RDS module,
# but allow ingress from backend app security group.
# This dependency will be circular if defined in the RDS module.
# We'll manage ingress for RDS from the backend ECS SG in the backend module.
# The RDS module will primarily create the SG and not add specific ingress rules.

# Add ingress rule to RDS Security Group from Backend ECS Instances
# This is done at the root module level to resolve potential circular dependencies
resource "aws_security_group_rule" "allow_backend_ecs_to_rds" {
  type                     = "ingress"
  from_port                = 5432 # PostgreSQL default port
  to_port                  = 5432
  protocol                 = "tcp"
  source_security_group_id = module.ecs_backend.ecs_instance_sg_id # Backend ECS Instance SG ID
  security_group_id        = module.rds.db_security_group_id
  description              = "Allow Backend ECS instances to access RDS"
}

# 5. ECS Frontend (Presentation Tier)
module "ecs_frontend" {
  source            = "../modules/ecs-frontend"
  name              = var.name
  vpc_id            = module.vpc.vpc_id
  public_subnet_ids = module.vpc.public_subnet_ids
  container_port    = var.frontend_container_port
  instance_type     = var.frontend_instance_type
  desired_capacity  = var.frontend_desired_capacity
  max_capacity      = var.frontend_max_capacity
  min_capacity      = var.frontend_min_capacity
  # Pass CloudWatch Log Group Name
  ecs_log_group_name = module.cloudwatch_logs.frontend_log_group_name
}

# 6. ECS Backend (Application Tier)
module "ecs_backend" {
  source                        = "../modules/ecs-backend"
  name                          = var.name
  vpc_id                        = module.vpc.vpc_id
  private_app_subnet_ids        = module.vpc.private_app_subnet_ids
  container_port                = var.backend_container_port
  instance_type                 = var.backend_instance_type
  desired_capacity              = var.backend_desired_capacity
  max_capacity                  = var.backend_max_capacity
  min_capacity                  = var.backend_min_capacity
  rds_endpoint                  = module.rds.db_instance_address
  db_name                       = var.db_name
  db_username                   = var.db_username
  secrets_manager_db_secret_arn = module.secrets_manager.db_secret_arn
  # Pass CloudWatch Log Group Name
  ecs_log_group_name = module.cloudwatch_logs.backend_log_group_name

  # Allow ingress from frontend ALB SG to internal ALB SG
  # This needs to be done here at the root level because of cross-module dependencies
  # We need the security group IDs from the respective modules.
  # The security groups themselves are created in the individual ALB modules.
  frontend_alb_sg_id = module.ecs_frontend.public_alb_sg_id
  rds_vpc_cidr       = module.vpc.vpc_cidr # Pass VPC CIDR for backend egress to RDS

  vpc_cidr = module.vpc.vpc_cidr # Pass the VPC CIDR for internal ALB SG ingress to break the cycle
}

# 7 Security Monitoring
module "security_monitoring" {
  source     = "../modules/security-monitoring"
  name       = var.name
  aws_region = var.aws_region
}

# 8. Auto-Remediation Lambda
module "auto_remediation" {
  source     = "../modules/auto-remediation"
  name       = var.name
  aws_region = var.aws_region
  vpc_id     = module.vpc.vpc_id # Pass VPC ID for some remediation actions (e.g., SG updates)
  # Security Group IDs for auto-remediation targeting
  # This will allow the lambda to revoke SSH 0.0.0.0/0 on any SG within the VPC if detected
  # We can refine this later to target specific SGs if needed, but for now, any SG.
  security_group_ids_to_monitor = [
    module.ecs_frontend.public_alb_sg_id,
    module.ecs_frontend.ecs_instance_sg_id,
    module.ecs_backend.internal_alb_sg_id,
    module.ecs_backend.ecs_instance_sg_id,
    module.rds.db_security_group_id
  ]
}
