# variables.tf - Security Hub, GuardDuty, CloudTrail module variables

variable "project_name" {
  description = "A unique name for your project, used for resource naming."
  type        = string
}

variable "env" {
  description = "The environment name (e.g., dev, staging, prod)."
  type        = string
}

variable "aws_region" {
  description = "The AWS region to deploy resources into."
  type        = string
}
