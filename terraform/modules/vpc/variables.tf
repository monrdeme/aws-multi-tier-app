# variables.tf - VPC module variables

variable "name" {
  description = "A unique name used for resource naming."
  type        = string
}

variable "aws_region" {
  description = "The AWS region to deploy resources into."
  type        = string
}

variable "vpc_cidr" {
  description = "The CIDR block for the VPC."
  type        = string
}

variable "public_subnet_cidrs" {
  description = "A list of CIDR blocks for the public subnets."
  type        = list(string)
}

variable "private_app_subnet_cidrs" {
  description = "A list of CIDR blocks for the private application subnets."
  type        = list(string)
}

variable "private_db_subnet_cidrs" {
  description = "A list of CIDR blocks for the private database subnets."
  type        = list(string)
}
