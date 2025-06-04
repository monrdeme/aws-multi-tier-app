# variables.tf - CloudWatch Logs module variables

variable "project_name" {
  description = "A unique name for your project, used for resource naming."
  type        = string
}

variable "env" {
  description = "The environment name (e.g., dev, staging, prod)."
  type        = string
}
