# outputs.tf - ECS Frontend module outputs

output "public_alb_dns_name" {
  description = "The DNS name of the public (frontend) ALB."
  value       = aws_lb.public_frontend.dns_name
}

output "public_alb_sg_id" {
  description = "The ID of the security group for the public ALB."
  value       = aws_security_group.public_alb_sg.id
}

output "ecs_cluster_name" {
  description = "The name of the frontend ECS cluster."
  value       = aws_ecs_cluster.frontend.name
}

output "ecs_instance_sg_id" {
  description = "The ID of the security group for frontend ECS instances."
  value       = aws_security_group.frontend_ecs_instance_sg.id
}

output "ecr_repository_url" {
  description = "The URL of the ECR repository for the frontend application."
  value       = aws_ecr_repository.frontend_app.repository_url
}
