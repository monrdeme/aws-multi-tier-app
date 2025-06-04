# main.tf - ECS Backend Module

# ECR Repository for the Backend Docker image
resource "aws_ecr_repository" "backend_app" {
  name                 = "${var.project_name}-${var.env}-backend-app"
  image_tag_mutability = "MUTABLE"
  force_delete         = false

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = {
    Name        = "${var.project_name}-${var.env}-backend-ecr"
    Project     = var.project_name
    Environment = var.env
    Layer       = "Application"
  }
}

# IAM Role for ECS Task Execution (allows ECS to pull images from ECR, log to CloudWatch, access Secrets Manager)
resource "aws_iam_role" "backend_ecs_task_execution_role" {
  name = "${var.project_name}-${var.env}-backend-ecs-task-role"

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
    Name        = "${var.project_name}-${var.env}-backend-ecs-task-role"
    Project     = var.project_name
    Environment = var.env
    Layer       = "Application"
  }
}

resource "aws_iam_role_policy_attachment" "backend_ecs_task_execution_role_policy" {
  role       = aws_iam_role.backend_ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Policy to allow access to Secrets Manager for DB credentials
resource "aws_iam_policy" "backend_secrets_manager_access" {
  name        = "${var.project_name}-${var.env}-backend-secrets-manager-access-policy"
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
  name = "${var.project_name}-${var.env}-backend-cluster"

  tags = {
    Name        = "${var.project_name}-${var.env}-backend-cluster"
    Project     = var.project_name
    Environment = var.env
    Layer       = "Application"
  }
}

# IAM Role for EC2 instances that are part of the ECS cluster
resource "aws_iam_role" "backend_ecs_instance_role" {
  name = "${var.project_name}-${var.env}-backend-ecs-instance-role"

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
    Name        = "${var.project_name}-${var.env}-backend-ecs-instance-role"
    Project     = var.project_name
    Environment = var.env
    Layer       = "Application"
  }
}

resource "aws_iam_instance_profile" "backend_ecs_instance_profile" {
  name = "${var.project_name}-${var.env}-backend-ecs-instance-profile"
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
  name        = "${var.project_name}-${var.env}-backend-ecs-instance-sg"
  description = "Allows traffic from internal ALB to backend ECS instances and egress to RDS"
  vpc_id      = var.vpc_id

  # Ingress from Internal ALB on container port
  ingress {
    from_port       = var.container_port
    to_port         = var.container_port
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
    Name        = "${var.project_name}-${var.env}-backend-ecs-instance-sg"
    Project     = var.project_name
    Environment = var.env
    Layer       = "Application"
  }
}

# Find latest Amazon Linux 2 ECS-Optimized AMI (same as frontend)
data "aws_ssm_parameter" "ecs_ami" {
  name = "/aws/service/ecs/optimized-ami/amazon-linux-2/recommended/image_id"
}

# EC2 Launch Template for Backend ECS Instances
resource "aws_launch_template" "backend_ecs_instance_template" {
  name_prefix   = "${var.project_name}-${var.env}-backend-ecs-lt"
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
      Name        = "${var.project_name}-${var.env}-backend-ecs-instance"
      Project     = var.project_name
      Environment = var.env
      Layer       = "Application"
    }
  }

  tag_specifications {
    resource_type = "volume"
    tags = {
      Name        = "${var.project_name}-${var.env}-backend-ecs-instance-volume"
      Project     = var.project_name
      Environment = var.env
      Layer       = "Application"
    }
  }
}

# Auto Scaling Group for Backend ECS Instances
resource "aws_autoscaling_group" "backend_ecs_asg" {
  name                      = "${var.project_name}-${var.env}-backend-ecs-asg"
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
    value               = "${var.project_name}-${var.env}-backend-ecs-instance"
    propagate_at_launch = true
  }
  tag {
    key                 = "Project"
    value               = var.project_name
    propagate_at_launch = true
  }
  tag {
    key                 = "Environment"
    value               = var.env
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
  name               = "${var.project_name}-${var.env}-int-alb"
  internal           = true # Internal-facing
  load_balancer_type = "application"
  security_groups    = [aws_security_group.internal_alb_sg.id]
  subnets            = var.private_app_subnet_ids # ALB lives in private application subnets

  tags = {
    Name        = "${var.project_name}-${var.env}-int-alb"
    Project     = var.project_name
    Environment = var.env
    Layer       = "Application"
  }
}

# Internal ALB Security Group (allows inbound traffic from Frontend ALB)
resource "aws_security_group" "internal_alb_sg" {
  name        = "${var.project_name}-${var.env}-int-alb-sg"
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
  # Add HTTPS if you plan to use internal SSL/TLS
  # ingress {
  #   from_port       = 443
  #   to_port         = 443
  #   protocol        = "tcp"
  #   security_groups = [var.frontend_alb_sg_id]
  #   description     = "Allow HTTPS from Frontend ALB"
  # }

  egress = [{
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"] # Allow outbound to backend ECS instances
    ipv6_cidr_blocks = []
    prefix_list_ids  = []
    security_groups  = []
    self             = false
    description      = "Allow all outbound traffic"
  }]

  tags = {
    Name        = "${var.project_name}-${var.env}-int-alb-sg"
    Project     = var.project_name
    Environment = var.env
    Layer       = "Application"
  }
}

# Internal ALB Target Group
resource "aws_lb_target_group" "backend_app" {
  name        = "${var.project_name}-${var.env}-back-app"
  port        = var.container_port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "instance"

  health_check {
    path                = "/health"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  tags = {
    Name        = "${var.project_name}-${var.env}-back-tg"
    Project     = var.project_name
    Environment = var.env
    Layer       = "Application"
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
    Name        = "${var.project_name}-${var.env}-int-alb-listener"
    Project     = var.project_name
    Environment = var.env
    Layer       = "Application"
  }
}

# ECS Task Definition (describes how to run your Docker container)
resource "aws_ecs_task_definition" "backend_app" {
  family                   = "${var.project_name}-${var.env}-backend-task"
  requires_compatibilities = ["EC2"]
  network_mode             = "bridge"
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = aws_iam_role.backend_ecs_task_execution_role.arn
  task_role_arn            = aws_iam_role.backend_ecs_task_execution_role.arn

  container_definitions = jsonencode([
    {
      name      = "${var.project_name}-${var.env}-backend-container"
      image     = "${aws_ecr_repository.backend_app.repository_url}:latest"
      cpu       = 256
      memory    = 512
      essential = true
      portMappings = [
        {
          containerPort = var.container_port
          hostPort      = var.container_port
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
      secrets = [ # Use secrets from Secrets Manager for sensitive data like DB password
        {
          name      = "DB_PASSWORD"
          valueFrom = var.secrets_manager_db_secret_arn # Reference the Secrets Manager ARN
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
    Name        = "${var.project_name}-${var.env}-backend-task-def"
    Project     = var.project_name
    Environment = var.env
    Layer       = "Application"
  }
}

# ECS Service
resource "aws_ecs_service" "backend_app" {
  name            = "${var.project_name}-${var.env}-backend-service"
  cluster         = aws_ecs_cluster.backend.id
  task_definition = aws_ecs_task_definition.backend_app.arn
  desired_count   = var.desired_capacity
  depends_on      = [aws_lb_listener.http_backend]

  load_balancer {
    target_group_arn = aws_lb_target_group.backend_app.arn
    container_name   = "${var.project_name}-${var.env}-backend-container"
    container_port   = var.container_port
  }

  tags = {
    Name        = "${var.project_name}-${var.env}-backend-ecs-service"
    Project     = var.project_name
    Environment = var.env
    Layer       = "Application"
  }
}

# Data source for current AWS region (used in logConfiguration)
data "aws_region" "current" {}
