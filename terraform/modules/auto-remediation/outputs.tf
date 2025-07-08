# outputs.tf - Auto-Remediation Lambda module outputs

output "remediation_lambda_function_name" {
  description = "The name of the auto-remediation Lambda function."
  value       = aws_lambda_function.auto_remediation.function_name
}

output "remediation_lambda_arn" {
  description = "The ARN of the auto-remediation Lambda function."
  value       = aws_lambda_function.auto_remediation.arn
}
