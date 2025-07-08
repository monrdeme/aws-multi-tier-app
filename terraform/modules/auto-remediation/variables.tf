# variables.tf - Auto-Remediation Lambda module variables

variable "name" {
  description = "A unique name used for resource naming."
  type        = string
}

variable "aws_region" {
  description = "The AWS region where the Lambda function will be deployed."
  type        = string
}

variable "vpc_id" {
  description = "The ID of the VPC (used potentially for SG remediation targeting)."
  type        = string
}

variable "security_group_ids_to_monitor" {
  description = "List of security group IDs to specifically monitor for certain remediation actions. (Optional, can be '*' for broad scope)."
  type        = list(string)
  default     = []
}
