# outputs.tf - Secrets Manager module outputs

output "db_secret_arn" {
  description = "The ARN of the Secrets Manager secret storing the database credentials."
  value       = aws_secretsmanager_secret.db_master_password.arn
}
