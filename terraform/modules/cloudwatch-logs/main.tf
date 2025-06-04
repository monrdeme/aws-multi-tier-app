# main.tf - CloudWatch Logs module

resource "aws_cloudwatch_log_group" "frontend_app_logs" {
  name              = "/ecs/${var.project_name}-${var.env}-frontend-app"
  retention_in_days = 30 # CIS Benchmark: Define log retention periods. Adjust a needed for compliance/cost

  tags = {
    Name        = "${var.project_name}-${var.env}-frontend-logs"
    Project     = var.project_name
    Environment = var.env
  }
}

resource "aws_cloudwatch_log_group" "backend_app_logs" {
  name              = "/ecs/${var.project_name}-${var.env}-backend-app"
  retention_in_days = 30 # CIS Benchmark: Define log retention periods. Adjust a needed for compliance/cost

  tags = {
    Name        = "${var.project_name}-${var.env}-backend-logs"
    Project     = var.project_name
    Environment = var.env
  }
}
