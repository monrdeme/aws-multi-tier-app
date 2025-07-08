# variables.tf - RDS module variables

variable "name" {
  description = "A unique name used for resource naming."
  type        = string
}

variable "vpc_id" {
  description = "The ID of the VPC where the RDS instance will be deployed."
  type        = string
}

variable "private_db_subnet_ids" {
  description = "A list of private subnet IDs for the RDS database."
  type        = list(string)
}

variable "db_username" {
  description = "Master username for the RDS database."
}

variable "secrets_manager_db_secret_arn" {
  description = "The ARN of the Secrets Manager secret storing the database credentials."
  type        = string
}

variable "db_name" {
  description = "Name of the initial database to create."
  type        = string
}

variable "db_instance_type" {
  description = "RDS DB instance type (e.g., db.t3.micro)."
  type        = string
}

variable "db_allocated_storage" {
  description = "Allocated storage for the RDS instance in GB."
  type        = number
}
