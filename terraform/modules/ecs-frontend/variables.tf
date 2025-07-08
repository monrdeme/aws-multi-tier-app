# variables.tf - ECS Frontend module variables

variable "name" {
  description = "A unique name used for resource naming."
  type        = string
}

variable "vpc_id" {
  description = "The ID of the VPC."
  type        = string
}

variable "public_subnet_ids" {
  description = "IDs of the public subnets where frontend ECS instances will run."
  type        = list(string)
}

variable "container_port" {
  description = "The port the frontend Flask application listens on inside the container."
  type        = number
}

variable "instance_type" {
  description = "EC2 instance type for frontend ECS container instances."
  type        = string
}

variable "desired_capacity" {
  description = "Desired number of frontend ECS container instances."
  type        = number
}

variable "max_capacity" {
  description = "Maximum number of frontend ECS container instances."
  type        = number
}

variable "min_capacity" {
  description = "Minimum number of frontend ECS container instances."
  type        = number
}

variable "ecs_log_group_name" {
  description = "The name of the CloudWatch Log Group for frontend ECS."
  type        = string
}
