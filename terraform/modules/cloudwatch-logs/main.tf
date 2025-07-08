# main.tf - CloudWatch Logs module

resource "aws_cloudwatch_log_group" "frontend_app_logs" {
  name              = "/ecs/${var.name}-frontend-app"
  retention_in_days = 30 # CIS Benchmark: Define log retention periods. Adjust as needed for compliance/cost

  tags = {
    Name = "${var.name}-frontend-logs"
  }
}

resource "aws_cloudwatch_log_group" "backend_app_logs" {
  name              = "/ecs/${var.name}-backend-app"
  retention_in_days = 30 # CIS Benchmark: Define log retention periods. Adjust as needed for compliance/cost

  tags = {
    Name = "${var.name}-backend-logs"
  }
}
