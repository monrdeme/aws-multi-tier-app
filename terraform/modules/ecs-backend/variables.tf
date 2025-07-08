# variables.tf - ECS Backend module variables

variable "name" {
  description = "A unique name used for resource naming."
  type        = string
}

variable "vpc_id" {
  description = "The ID of the VPC."
  type        = string
}

variable "vpc_cidr" {
  description = "The CIDR block for the VPC."
  type        = string
}

variable "private_app_subnet_ids" {
  description = "IDs of the private application subnets where backend ECS instances will run."
  type        = list(string)
}

variable "container_port" {
  description = "The port the backend Flask application listens on inside the container."
  type        = number
}

variable "instance_type" {
  description = "EC2 instance type for backend ECS container instances."
  type        = string
}

variable "desired_capacity" {
  description = "Desired number of backend ECS container instances."
  type        = number
}

variable "max_capacity" {
  description = "Maximum number of backend ECS container instances."
  type        = number
}

variable "min_capacity" {
  description = "Minimum number of backend ECS container instances."
  type        = number
}

variable "rds_endpoint" {
  description = "The endpoint address of the RDS database instance."
  type        = string
}

variable "db_name" {
  description = "Name of the database for the backend application to connect to."
  type        = string
}

variable "db_username" {
  description = "Username for the database connection (retrieved via Secrets Manager)."
  type        = string
}

variable "secrets_manager_db_secret_arn" {
  description = "The ARN of the Secrets Manager secret storing the database credentials."
  type        = string
}

variable "ecs_log_group_name" {
  description = "The name of the CloudWatch Log Group for backend ECS."
  type        = string
}

variable "frontend_alb_sg_id" {
  description = "The Security Group ID of the Frontend ALB, for internal ALB ingress."
  type        = string
}

variable "rds_vpc_cidr" {
  description = "The CIDR block of the VPC where RDS resides, for backend egress rules."
  type        = string
}
