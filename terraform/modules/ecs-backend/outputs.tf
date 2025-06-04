# outputs.tf - ECS Backend module outputs

output "internal_alb_dns_name" {
  description = "The DNS name of the internal (backend) ALB."
  value       = aws_lb.internal_backend.dns_name
}

output "internal_alb_sg_id" {
  description = "The ID of the security group for the internal ALB."
  value       = aws_security_group.internal_alb_sg.id
}

output "ecs_cluster_name" {
  description = "The name of the backend ECS cluster."
  value       = aws_ecs_cluster.backend.name
}

output "ecs_instance_sg_id" {
  description = "The ID of the security group for backend ECS instances."
  value       = aws_security_group.backend_ecs_instance_sg.id
}

output "ecr_repository_url" {
  description = "The URL of the ECR repository for the backend application."
  value       = aws_ecr_repository.backend_app.repository_url
}
