# outputs.tf - Root module outputs

output "vpc_id" {
  description = "The ID of the VPC."
  value       = module.vpc.vpc_id
}

output "public_subnet_ids" {
  description = "IDs of the public subnets."
  value       = module.vpc.public_subnet_ids
}

output "private_app_subnet_ids" {
  description = "IDs of the private application subnets."
  value       = module.vpc.private_app_subnet_ids
}

output "private_db_subnet_ids" {
  description = "IDs of the private database subnets."
  value       = module.vpc.private_db_subnet_ids
}

output "frontend_alb_dns_name" {
  description = "The DNS name of the public (frontend) ALB."
  value       = module.ecs_frontend.public_alb_dns_name
}

output "backend_alb_dns_name" {
  description = "The DNS name of the internal (backend) ALB."
  value       = module.ecs_backend.internal_alb_dns_name
}

output "rds_endpoint_address" {
  description = "The address of the RDS database instance."
  value       = module.rds.db_instance_address
}

output "rds_db_master_secret_arn" {
  description = "The ARN of the Secrets Manager secret for the RDS master password."
  value       = module.secrets_manager.db_secret_arn
}

output "frontend_ecs_cluster_name" {
  description = "Name of the frontend ECS cluster."
  value       = module.ecs_frontend.ecs_cluster_name
}

output "backend_ecs_cluster_name" {
  description = "Name of the backend ECS cluster."
  value       = module.ecs_backend.ecs_cluster_name
}
