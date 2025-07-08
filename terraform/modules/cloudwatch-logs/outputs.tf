# outputs.tf - CloudWatch Logs module outputs

output "frontend_log_group_name" {
  description = "The name of the CloudWatch Log Group for the frontend application logs."
  value       = aws_cloudwatch_log_group.frontend_app_logs.name
}

output "backend_log_group_name" {
  description = "The name of the CloudWatch Log Group for backend application logs."
  value       = aws_cloudwatch_log_group.backend_app_logs.name
}
