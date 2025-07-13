# main.tf - Auto-Remediation Lambda module

# Zip the Lambda function code
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/lambda_function_code"
  output_path = "${path.module}/lambda.zip"
}

# IAM Role for the Lambda function
resource "aws_iam_role" "remediation_lambda_role" {
  name = "${var.name}-remediation-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      },
    ]
  })

  tags = {
    Name    = "${var.name}-remediation-lambda-role"
    Service = "AutoRemediation"
  }
}

# Policy for Lambda to write logs to CloudWatch Logs
resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.remediation_lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Custom Policy for Remediation Actions
resource "aws_iam_policy" "remediation_policy" {
  name        = "${var.name}-remediation-policy"
  description = "Policy for auto-remediation Lambda to perform security actions"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # Permissions for revoke_security_group_ingress (SSH remediation)
      {
        Effect = "Allow"
        Action = [
          "ec2:RevokeSecurityGroupIngress",
          "ec2:DescribeSecurityGroups" # Needed for detailed SG info if required
        ]
        Resource = "*" # Restrict to instances in specific VPCs/subnets if known
      },
      # Permissions for stop_unapproved_ami_instance (AMI remediation)
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances",
          "ec2:StopInstances",
          "ec2:DescribeInstanceStatus"
        ]
        Resource = "*" # Restrict to specific instances/regions if known
      },
      # Permissions for S3 remediation (if implemented)
      # {
      #   Effect = "Allow"
      #   Action = [
      #     "s3:PutBucketPolicy",
      #     "s3:PutBucketAcl",
      #     "s3:GetBucketPolicy",
      #     "s3:GetBucketAcl",
      #     "s3:GetBucketPublicAccessBlock"
      #   ]
      #   Resource = "*" # Restrict to specific buckets if known
      # },
      # Permissions for GuardDuty findings (if implemented, e.g., IAM key revocation)
      # {
      #   Effect = "Allow"
      #   Action = [
      #     "iam:UpdateAccessKey",
      #     "iam:DeleteAccessKey"
      #   ]
      #   Resource = "*" # Highly sensitive, restrict to specific IAM users if possible
      # }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "remediation_policy_attach" {
  role       = aws_iam_role.remediation_lambda_role.name
  policy_arn = aws_iam_policy.remediation_policy.arn
}

# Lambda Function
resource "aws_lambda_function" "auto_remediation" {
  filename      = data.archive_file.lambda_zip.output_path
  function_name = "${var.name}-auto-remediation-lambda"
  role          = aws_iam_role.remediation_lambda_role.arn
  handler       = "main.lambda_handler" # File name (main.py) and function name (lambda_handler)
  runtime       = "python3.11"
  timeout       = 60
  memory_size   = 128

  # Environment variable for APPROVED_AMI_ID
  environment {
    variables = {
      APPROVED_AMI_ID = data.aws_ami.ecs_optimized_ami_id.id # Get the AMI ID from the ECS module
    }
  }

  tags = {
    Name    = "${var.name}-auto-remediation-lambda"
    Service = "AutoRemediation"
  }
}

# Data source to get the current approved ECS Optimized AMI ID
# This ensures consistency with the AMIs used in the ECS modules
data "aws_ssm_parameter" "ecs_ami" {
  name = "/aws/service/ecs/optimized-ami/amazon-linux-2/recommended/image_id"
}

data "aws_ami" "ecs_optimized_ami_id" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "image-id"
    values = [data.aws_ssm_parameter.ecs_ami.value]
  }
}

# CloudWatch Event Rule for SSH 0.0.0.0/0 Remediation
resource "aws_cloudwatch_event_rule" "ssh_remediation_rule" {
  name        = "${var.name}-ssh-remediation-rule"
  description = "Triggers on EC2 AuthorizeSecurityGroupIngress for SSH 0.0.0.0/0"

  event_pattern = jsonencode({
    "source" : ["aws.ec2"],
    "detail-type" : ["AWS API Call via CloudTrail"],
    "detail" : {
      "eventName" : ["AuthorizeSecurityGroupIngress"]
    }
  })

  tags = {
    Name    = "${var.name}-ssh-remediation-rule"
    Service = "AutoRemediation"
  }
}

# CloudWatch Event Rule for Unapproved AMI Remediation
resource "aws_cloudwatch_event_rule" "unapproved_ami_remediation_rule" {
  name        = "${var.name}-unapproved-ami-remediation-rule"
  description = "Triggers on all EC2 RunInstances for AMI validation"

  event_pattern = jsonencode({
    "source" : ["aws.ec2"],
    "detail-type" : ["AWS API Call via CloudTrail"],
    "detail" : {
      "eventName" : ["RunInstances"]
    }
  })

  tags = {
    Name    = "${var.name}-unapproved-ami-remediation-rule"
    Service = "AutoRemediation"
  }
}

# CloudWatch Event Targets (link rules to Lambda function)
resource "aws_cloudwatch_event_target" "ssh_remediation_target" {
  rule = aws_cloudwatch_event_rule.ssh_remediation_rule.name
  arn  = aws_lambda_function.auto_remediation.arn
}

resource "aws_cloudwatch_event_target" "unapproved_ami_remediation_target" {
  rule = aws_cloudwatch_event_rule.unapproved_ami_remediation_rule.name
  arn  = aws_lambda_function.auto_remediation.arn
}

# Lambda Permission to allow CloudWatch Events to invoke it
resource "aws_lambda_permission" "allow_cloudwatch_ssh" {
  statement_id  = "AllowExecutionFromCloudWatchSSH"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.auto_remediation.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.ssh_remediation_rule.arn
}

resource "aws_lambda_permission" "allow_cloudwatch_ami" {
  statement_id  = "AllowExecutionFromCloudWatchAMI"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.auto_remediation.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.unapproved_ami_remediation_rule.arn
}
