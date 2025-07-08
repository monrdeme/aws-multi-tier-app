# main.tf - ECS Backend Module

# ECR Repository for the Backend Docker image
resource "aws_ecr_repository" "backend_app" {
  name                 = "${var.name}-backend-app"
  image_tag_mutability = "MUTABLE"
  force_delete         = false

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = {
    Name  = "${var.name}-backend-ecr"
    Layer = "Application"
  }
}

# IAM Role for ECS Task Execution (allows ECS to pull images from ECR, log to CloudWatch, access Secrets Manager)
resource "aws_iam_role" "backend_ecs_task_execution_role" {
  name = "${var.name}-backend-ecs-task-exec-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      },
    ]
  })

  tags = {
    Name  = "${var.name}-backend-ecs-task-role"
    Layer = "Application"
  }
}

resource "aws_iam_role_policy_attachment" "backend_ecs_task_execution_role_policy" {
  role       = aws_iam_role.backend_ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Policy to allow access to Secrets Manager for DB credentials
resource "aws_iam_policy" "backend_secrets_manager_access" {
  name        = "${var.name}-backend-secrets-manager-access-policy"
  description = "Policy for backend ECS tasks to read database secrets from Secrets Manager"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = var.secrets_manager_db_secret_arn
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "backend_ecs_task_secrets_manager_attach" {
  role       = aws_iam_role.backend_ecs_task_execution_role.name
  policy_arn = aws_iam_policy.backend_secrets_manager_access.arn
}

# ECS Cluster for Backend
resource "aws_ecs_cluster" "backend" {
  name = "${var.name}-backend-cluster"

  tags = {
    Name  = "${var.name}-backend-cluster"
    Layer = "Application"
  }
}

# IAM Role for EC2 instances that are part of the ECS cluster
resource "aws_iam_role" "backend_ecs_instance_role" {
  name = "${var.name}-backend-ecs-instance-role"

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
    Name  = "${var.name}-backend-ecs-instance-role"
    Layer = "Application"
  }
}

resource "aws_iam_instance_profile" "backend_ecs_instance_profile" {
  name = "${var.name}-backend-ecs-instance-profile"
  role = aws_iam_role.backend_ecs_instance_role.name
}

resource "aws_iam_role_policy_attachment" "backend_ecs_instance_policy" {
  role       = aws_iam_role.backend_ecs_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

# Attach SSM Core policy for host management (no SSH needed)
resource "aws_iam_role_policy_attachment" "backend_ecs_instance_ssm_policy" {
  role       = aws_iam_role.backend_ecs_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Security Group for Backend ECS Instances (allowig traffic from Internal ALB and egress to RDS)
resource "aws_security_group" "backend_ecs_instance_sg" {
  name        = "${var.name}-backend-ecs-instance-sg"
  description = "Allows traffic from internal ALB to backend ECS instances and egress to RDS"
  vpc_id      = var.vpc_id

  # Ingress from Internal ALB on the ephemeral port range
  # Allow traffic on the ephemeral port range that ECS uses for dynamic port mappings
  # Standard ephemeral port range: 32768-65535 (for Amazon Linux 2)
  ingress {
    from_port       = 32768 # Starting port of the ephemeral range
    to_port         = 65535 # Ending port of the ephemeral range
    protocol        = "tcp"
    security_groups = [aws_security_group.internal_alb_sg.id]
    description     = "Allow HTTP/app traffic from Internal ALB"
  }
  # Egress to RDS on PostgresSQL port (5432)
  egress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [var.rds_vpc_cidr] # Use VPC CIDR for RDS (more specific rule will be in RDS SG)
    description = "Allow outbound to RDS PostgresSQL"
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
    Name  = "${var.name}-backend-ecs-instance-sg"
    Layer = "Application"
  }
}

# Find latest Amazon Linux 2 ECS-Optimized AMI (same as frontend)
data "aws_ssm_parameter" "ecs_ami" {
  name = "/aws/service/ecs/optimized-ami/amazon-linux-2/recommended/image_id"
}

# EC2 Launch Template for Backend ECS Instances
resource "aws_launch_template" "backend_ecs_instance_template" {
  name_prefix   = "${var.name}-backend-ecs-lt"
  image_id      = data.aws_ssm_parameter.ecs_ami.value
  instance_type = var.instance_type
  key_name      = "" # CIS Benchmark: No SSH key pair unless strictly necessary

  iam_instance_profile {
    name = aws_iam_instance_profile.backend_ecs_instance_profile.name
  }

  user_data = base64encode(templatefile("${path.module}/user_data.sh", {
    ecs_cluster_name = aws_ecs_cluster.backend.name
  }))

  # Block public IP assignment. Instances are in private subnets.
  network_interfaces {
    associate_public_ip_address = false
    security_groups             = [aws_security_group.backend_ecs_instance_sg.id]
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name  = "${var.name}-backend-ecs-instance"
      Layer = "Application"
    }
  }

  tag_specifications {
    resource_type = "volume"
    tags = {
      Name  = "${var.name}-backend-ecs-instance-volume"
      Layer = "Application"
    }
  }
}

# Auto Scaling Group for Backend ECS Instances
resource "aws_autoscaling_group" "backend_ecs_asg" {
  name                      = "${var.name}-backend-ecs-asg"
  vpc_zone_identifier       = var.private_app_subnet_ids
  desired_capacity          = var.desired_capacity
  max_size                  = var.max_capacity
  min_size                  = var.min_capacity
  health_check_type         = "EC2"
  health_check_grace_period = 300
  target_group_arns         = [aws_lb_target_group.backend_app.arn] # Attach ASG to Internal ALB Target Group

  launch_template {
    id      = aws_launch_template.backend_ecs_instance_template.id
    version = "$Latest"
  }

  tag {
    key                 = "AmazonECSManaged"
    value               = ""
    propagate_at_launch = true
  }
  tag {
    key                 = "Name"
    value               = "${var.name}-backend-ecs-instance"
    propagate_at_launch = true
  }
  tag {
    key                 = "Layer"
    value               = "Application"
    propagate_at_launch = true
  }
}

# Internal Application Load Balancer (ALB)
resource "aws_lb" "internal_backend" {
  name               = "${var.name}-int-alb"
  internal           = true # Internal-facing
  load_balancer_type = "application"
  security_groups    = [aws_security_group.internal_alb_sg.id]
  subnets            = var.private_app_subnet_ids # ALB lives in private application subnets

  tags = {
    Name  = "${var.name}-int-alb"
    Layer = "Application"
  }
}

# Internal ALB Security Group (allows inbound traffic from Frontend ALB)
resource "aws_security_group" "internal_alb_sg" {
  name        = "${var.name}-int-alb-sg"
  description = "Allows traffic from Frontend ALB to Internal ALB"
  vpc_id      = var.vpc_id

  # Ingress from Frontend ALB on HTTP/app port
  ingress {
    from_port       = 80 # Assuming internal comnmunication over HTTP
    to_port         = 80
    protocol        = "tcp"
    security_groups = [var.frontend_alb_sg_id] # Source is the frontend ALB's SG
    description     = "Allow HTTP from Frontend ALB"
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
    description = "Allow HTTP from Backend Service Tasks (self-access/internal calls)"
  }
  # Add HTTPS if you plan to use internal SSL/TLS
  # ingress {
  #   from_port       = 443
  #   to_port         = 443
  #   protocol        = "tcp"
  #   security_groups = [var.frontend_alb_sg_id]
  #   description     = "Allow HTTPS from Frontend ALB"
  # }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"] # Allow outbound to backend ECS instances
    description = "Allow all outbound traffic"
  }

  tags = {
    Name  = "${var.name}-int-alb-sg"
    Layer = "Application"
  }
}

# Internal ALB Target Group
resource "aws_lb_target_group" "backend_app" {
  name        = "${var.name}-backend-tg"
  port        = var.container_port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "instance"

  health_check {
    path                = "/health"
    protocol            = "HTTP"
    matcher             = 200
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  tags = {
    Name  = "${var.name}-backend-tg"
    Layer = "Application"
  }
}

# Internal ALB Listener (HTTP on port 80)
resource "aws_lb_listener" "http_backend" {
  load_balancer_arn = aws_lb.internal_backend.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    target_group_arn = aws_lb_target_group.backend_app.arn
    type             = "forward"
  }

  tags = {
    Name  = "${var.name}-int-alb-listener"
    Layer = "Application"
  }
}

# ECS Task Definition (describes how to run your Docker container)
resource "aws_ecs_task_definition" "backend_app" {
  family                   = "${var.name}-backend-task"
  requires_compatibilities = ["EC2"]
  network_mode             = "bridge"
  cpu                      = 256
  memory                   = 256
  execution_role_arn       = aws_iam_role.backend_ecs_task_execution_role.arn
  task_role_arn            = aws_iam_role.backend_ecs_task_execution_role.arn

  container_definitions = jsonencode([
    {
      name      = "${var.name}-backend-container"
      image     = "${aws_ecr_repository.backend_app.repository_url}:latest"
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
          name  = "PORT"
          value = tostring(var.container_port)
        },
        {
          name  = "DB_HOST"
          value = var.rds_endpoint
        },
        {
          name  = "DB_NAME"
          value = var.db_name
        },
        {
          name  = "DB_USER"
          value = var.db_username
        }
      ]
      secrets = [ # Use secrets from Secrets Manager for sensitive data like DB passwords 
        {
          name      = "DB_PASSWORD"
          valueFrom = "${var.secrets_manager_db_secret_arn}:password::" # Reference the Secrets Manager ARN
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = var.ecs_log_group_name
          "awslogs-region"        = data.aws_region.current.name
          "awslogs-stream-prefix" = "ecs-backend"
        }
      }
    }
  ])

  tags = {
    Name  = "${var.name}-backend-task-def"
    Layer = "Application"
  }
}

# ECS Service
resource "aws_ecs_service" "backend_app" {
  name            = "${var.name}-backend-service"
  cluster         = aws_ecs_cluster.backend.id
  task_definition = aws_ecs_task_definition.backend_app.arn
  desired_count   = var.desired_capacity
  depends_on      = [aws_lb_listener.http_backend]

  load_balancer {
    target_group_arn = aws_lb_target_group.backend_app.arn
    container_name   = "${var.name}-backend-container"
    container_port   = var.container_port
  }

  tags = {
    Name  = "${var.name}-backend-ecs-service"
    Layer = "Application"
  }
}

# Data source for current AWS region (used in logConfiguration)
data "aws_region" "current" {}
