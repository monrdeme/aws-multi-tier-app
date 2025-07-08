# outputs.tf - RDS module outputs

output "db_instance_address" {
  description = "The DNS address of the RDS database instance."
  value       = aws_db_instance.main.address
}

output "db_security_group_id" {
  description = "The ID of the security group for the RDS database."
  value       = aws_security_group.db_sg.id
}
