# main.tf - ECS Frontend Module

# ECR Repository for the Frontend Docker image
resource "aws_ecr_repository" "frontend_app" {
  name                 = "${var.name}-frontend-app"
  image_tag_mutability = "MUTABLE" # Can be IMMUTABLE for stricter control
  force_delete         = false     # Set to true with caution, deletes repository even if it contains images

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256" # Default AWS-managed key
  }

  tags = {
    Name  = "${var.name}-frontend-ecr"
    Layer = "Presentation"
  }
}

# IAM Role for ECS Task Execution (allows ECS to pull images from ECR, log to CloudWatch, etc.)
resource "aws_iam_role" "frontend_ecs_task_execution_role" {
  name = "${var.name}-frontend-ecs-task-exec-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name  = "${var.name}-frontend-ecs-task-exec-role"
    Layer = "Presentation"
  }
}

resource "aws_iam_role_policy_attachment" "frontend_ecs_task_execution_role_policy" {
  role       = aws_iam_role.frontend_ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# ECS Cluster for Frontend
resource "aws_ecs_cluster" "frontend" {
  name = "${var.name}-frontend-cluster"

  tags = {
    Name  = "${var.name}-frontend-cluster"
    Layer = "Presentation"
  }
}

# IAM Role for EC2 instances that are part of the ECS cluster
resource "aws_iam_role" "frontend_ecs_instance_role" {
  name = "${var.name}-frontend-ecs-instance-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })

  tags = {
    Name  = "${var.name}-frontend-ecs-instance-role"
    Layer = "Presentation"
  }
}

resource "aws_iam_instance_profile" "frontend_ecs_instance_profile" {
  name = "${var.name}-frontend-ecs-instance-profile"
  role = aws_iam_role.frontend_ecs_instance_role.name
}

resource "aws_iam_role_policy_attachment" "frontend_ecs_instance_policy" {
  role       = aws_iam_role.frontend_ecs_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

# Attach SSM Core policy for host management (no SSH needed)
resource "aws_iam_role_policy_attachment" "frontend_ecs_instance_ssm_policy" {
  role       = aws_iam_role.frontend_ecs_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Security Group for Frontend ECS Instances (allowing traffic from ALB only)
resource "aws_security_group" "frontend_ecs_instance_sg" {
  name        = "${var.name}-frontend-ecs-instance-sg"
  description = "Allow traffic from public ALB to frontend ECS instances"
  vpc_id      = var.vpc_id

  # Ingress from ALB on container port
  ingress {
    from_port       = 32768
    to_port         = 65535
    protocol        = "tcp"
    security_groups = [aws_security_group.public_alb_sg.id]
    description     = "Allow HTTP/app traffic from public ALB"
  }

  # Egress to anywhere (e.g., to NAT Gateway for outbound updates/ECR pull)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    Name  = "${var.name}-frontend-ecs-instance-sg"
    Layer = "Presentation"
  }
}

# Find latest Amazon Linux 2 ECS-Optimized AMI
data "aws_ssm_parameter" "ecs_ami" {
  name = "/aws/service/ecs/optimized-ami/amazon-linux-2/recommended/image_id"
}

# EC2 Launch Template for Frontend ECS Instances
resource "aws_launch_template" "frontend_ecs_instance_template" {
  name_prefix   = "${var.name}-frontend-ecs-lt"
  image_id      = data.aws_ssm_parameter.ecs_ami.value
  instance_type = var.instance_type
  key_name      = "" # CIS Benchmark: No SSH key pair unless strictly necessary

  iam_instance_profile {
    name = aws_iam_instance_profile.frontend_ecs_instance_profile.name
  }
  user_data = base64encode(templatefile("${path.module}/user_data.sh", {
    ecs_cluster_name = aws_ecs_cluster.frontend.name
  }))
  # Public IP assignment for instances in public subnets
  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.frontend_ecs_instance_sg.id]
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name  = "${var.name}-frontend-ecs-instance"
      Layer = "Presentation"
    }
  }

  tag_specifications {
    resource_type = "volume"
    tags = {
      Name = "${var.name}-frontend-ecs-instance-volume"
    }
  }
}

# Auto Scaling Group for Frontend ECS Instances
resource "aws_autoscaling_group" "frontend_ecs_asg" {
  name                      = "${var.name}-frontend-ecs-asg"
  vpc_zone_identifier       = var.public_subnet_ids
  desired_capacity          = var.desired_capacity
  max_size                  = var.max_capacity
  min_size                  = var.min_capacity
  health_check_type         = "EC2"
  health_check_grace_period = 300
  target_group_arns         = [aws_lb_target_group.frontend_app.arn] # Attach ASG to Public ALB Target Group

  launch_template {
    id      = aws_launch_template.frontend_ecs_instance_template.id
    version = "$Latest"
  }

  tag {
    key                 = "AmazonECSManaged"
    value               = ""
    propagate_at_launch = true
  }
  tag {
    key                 = "Name"
    value               = "${var.name}-frontend-ecs-instance"
    propagate_at_launch = true
  }
  tag {
    key                 = "Layer"
    value               = "Presentation"
    propagate_at_launch = true
  }
}

# Public Application Load Balancer (ALB)
resource "aws_lb" "public_frontend" {
  name               = "${var.name}-pub-alb"
  internal           = false # Internet-facing
  load_balancer_type = "application"
  security_groups    = [aws_security_group.public_alb_sg.id]
  subnets            = var.public_subnet_ids # ALB lives in public subnets

  tags = {
    Name  = "${var.name}-pub-alb"
    Layer = "Presentation"
  }
}

# Public ALB Security Group (allows inbound HTTP/HTTPS from internet)
resource "aws_security_group" "public_alb_sg" {
  name        = "${var.name}-pub-alb-sg"
  description = "Allow HTTP/HTTPS access to public ALB"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Allow HTTP from anywhere (CIS Benchmark review: consider restricting if known IPs)
    description = "Allow HTTP from internet"
  }
  /*
  Uncomment and configure if you have an ACM certificate for HTTPS
  ingress {
    from_port = 443
    to_port = 443
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow HTTPS from internet"
  }
  */

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"] # Allow outbound to ECS instances
    description = "Allow all outbound traffic"
  }

  tags = {
    Name  = "${var.name}-pub-alb-sg"
    Layer = "Presentation"
  }
}

# Public ALB Target Group
resource "aws_lb_target_group" "frontend_app" {
  name        = "${var.name}-frontend-tg"
  port        = var.container_port # The port the app runs on inside the container
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "instance" # Since we are using EC2-backed ECS

  health_check {
    path                = "/health" # Health check endpoint in Flask app
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  tags = {
    Name  = "${var.name}-frontend-tg"
    Layer = "Presentation"
  }
}

# Public ALB Listener (HTTP on port 80)
resource "aws_lb_listener" "http_frontend" {
  load_balancer_arn = aws_lb.public_frontend.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    target_group_arn = aws_lb_target_group.frontend_app.arn
    type             = "forward"
  }

  tags = {
    Name  = "${var.name}-pub-alb-listener"
    Layer = "Presentation"
  }
}

# ECS Task Definition (describes how to run your Docker container)
resource "aws_ecs_task_definition" "frontend_app" {
  family                   = "${var.name}-frontend-task"
  requires_compatibilities = ["EC2"]
  network_mode             = "bridge" # EC2 launch type typically uses bridge or host
  cpu                      = 256      # Example: 0.25 vCPU
  memory                   = 256      # Example: 256 MB
  execution_role_arn       = aws_iam_role.frontend_ecs_task_execution_role.arn
  task_role_arn            = aws_iam_role.frontend_ecs_task_execution_role.arn # Same role for simplicity for now

  container_definitions = jsonencode([
    {
      name      = "${var.name}-frontend-container"
      image     = "${aws_ecr_repository.frontend_app.repository_url}:latest"
      cpu       = 256
      memory    = 256
      essential = true
      portMappings = [
        {
          containerPort = var.container_port
          hostPort      = 0
          protocol      = "tcp"
        }
      ]
      environment = [
        {
          name  = "PORT" # Ensure Flask app listens on this port
          value = tostring((var.container_port))
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = var.ecs_log_group_name
          "awslogs-region"        = data.aws_region.current.name
          "awslogs-stream-prefix" = "ecs-frontend"
        }
      }
    }
  ])

  tags = {
    Name  = "${var.name}-frontend-task-def"
    Layer = "Presentation"
  }
}

# ECS Service
resource "aws_ecs_service" "frontend_app" {
  name            = "${var.name}-frontend-service"
  cluster         = aws_ecs_cluster.frontend.id
  task_definition = aws_ecs_task_definition.frontend_app.arn
  desired_count   = var.desired_capacity            # Number of tasks to run (adjust based on load)
  launch_type     = "EC2"                           # Specify EC2 or EC2-backed ECS
  depends_on      = [aws_lb_listener.http_frontend] # Ensure ALB listener is ready

  load_balancer {
    target_group_arn = aws_lb_target_group.frontend_app.arn
    container_name   = "${var.name}-frontend-container"
    container_port   = var.container_port
  }

  tags = {
    Name  = "${var.name}-frontend-ecs-service"
    Layer = "Presentation"
  }
}

# Data source for current AWS region (used in logConfiguration)
data "aws_region" "current" {}
