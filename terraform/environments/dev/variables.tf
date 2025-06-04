# variables.tf - Root module variables

variable "aws_region" {
  description = "The AWS region to deploy resources into."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "A unique name for your project, used for resource naming."
  type        = string
  default     = "multi-tier-app"
}

variable "env" {
  description = "The environment name (e.g., dev, staging, prod)."
  type        = string
  default     = "dev"
}

# VPC Variables
variable "vpc_cidr" {
  description = "The CIDR block for the VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "A list of CIDR blocks for the public subnets (per AZ)."
  type        = list(string)
  default     = ["10.0.3.0/24", "10.0.4.0/24"]
}

variable "private_app_subnet_cidrs" {
  description = "A list of CIDR blocks for the private application subnets (per AZ)."
  type        = list(string)
  default     = ["10.0.11.0/24", "10.0.12.0/24"]
}

variable "private_db_subnet_cidrs" {
  description = "A list of CIDR blocks for the private database subnets (per AZ)."
  type        = list(string)
  default     = ["10.0.21.0/24", "10.0.22.0/24"]
}

# RDS Variables
variable "db_username" {
  description = "Master username for the RDS database."
  type        = string
  default     = "devadmin"
}

variable "db_name" {
  description = "Name of the initial database to create."
  type        = string
  default     = "flaskappdb"
}

variable "db_instance_type" {
  description = "RDS DB instance type (e.g., db.t3.micro for free tier)."
  type        = string
  default     = "db.t3.micro"
}

variable "db_allocated_storage" {
  description = "Allocated storage for the RDS instance in GB."
  type        = number
  default     = 20 # Minimum for many instance types
}

# ECS Frontend Variables
variable "frontend_container_port" {
  description = "The port the frontend Flask application listens on inside the container."
  type        = number
  default     = 8000
}

variable "frontend_instance_type" {
  description = "EC2 instance type for frontend ECS container instances (e.g., t3.micro for free tier)."
  type        = string
  default     = "t3.micro"
}

variable "frontend_desired_capacity" {
  description = "Desired number of frontend ECS container instances."
  type        = number
  default     = 1
}

variable "frontend_max_capacity" {
  description = "Maximum number of frontend ECS container instances."
  type        = number
  default     = 2
}

variable "frontend_min_capacity" {
  description = "Minimum number of frontend ECS container instances."
  type        = number
  default     = 1
}

# ECS Backend Variables
variable "backend_container_port" {
  description = "The port the backend Flask application listens on inside the container."
  type        = number
  default     = 5000
}

variable "backend_instance_type" {
  description = "EC2 instance type for backend ECS container instances (e.g., t3.micro for free tier)."
  type        = string
  default     = "t3.micro"
}

variable "backend_desired_capacity" {
  description = "Desired number of backend ECS container instances."
  type        = number
  default     = 1
}

variable "backend_max_capacity" {
  description = "Maximum number of backend ECS container instances."
  type        = number
  default     = 2
}

variable "backend_min_capacity" {
  description = "Minimum number of backend ECS container instances."
  type        = number
  default     = 1
}
