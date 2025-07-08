# variables.tf - Security Monitoring module variables

variable "name" {
  description = "A unique name used for resource naming."
  type        = string
}

variable "aws_region" {
  description = "The AWS region to deploy resources into."
  type        = string
}
