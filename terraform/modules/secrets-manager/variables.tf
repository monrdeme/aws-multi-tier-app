# variables.tf - Secrets Manager module variables

variable "project_name" {
  description = "A unique name for your project, used for resource naming."
  type        = string
}

variable "env" {
  description = "The environment name (e.g., dev, staging, prod)."
  type        = string
}

variable "db_username" {
  description = "The username for the database master user."
  type        = string
  sensitive   = true # Mark as sensitive to prevent output in logs
}

variable "db_password" {
  description = "The password for the database master user."
  type        = string
  sensitive   = true # Mark as sensitive to prevent output in logs
}
