# main.tf - Security Monitoring module

# 1. AWS Security Hub
resource "aws_securityhub_account" "main" {
  provider = aws
  # Enable Security Hub in the current region
  # No attributes needed to just enable it. 
  # This resource will create a Security Hub account, enabling it if not already enabled.
}

resource "aws_securityhub_standards_subscription" "cis_aws_foundation" {
  # CIS AWS Foundations Benchmark v1.2.0 (example, check latest available)
  standards_arn = "arn:aws:securityhub:::ruleset/cis-aws-foundations-benchmark/v/1.2.0"
  # You might want to disable specific controls if they don't apply to your needs
  # But for this project, we'll keep them enabled to simulate adherence
  # For disabling, use aws_securityhub_control_finding_generator resource or manually in console.
  depends_on = [aws_securityhub_account.main] # Ensure Security Hub is enabled first
}

# 2 AWS GuardDuty
resource "aws_guardduty_detector" "main" {
  enable = true

  tags = {
    Name    = "${var.name}-guardduty-detector"
    Service = "GuardDuty"
  }
}
# Optionally, you can enable specific GuardDuty finding types or integrations
# resource "aws_guardduty_publishing_destination" "s3_destination" {
#   detector_id        = aws_guardduty_detector.main.id
#   destination_type   = "S3"
#   destination_arn    = aws_s3_bucket.guardduty_findings_bucket.arn # Needs a separate S3 bucket
#   kms_key_arn        = "arn:aws:kms:${var.aws_region}:${data.aws_caller_identity.current.account_id}:alias/aws/s3" # Or your own KMS key
# }
#
# resource "aws_s3_bucket" "guardduty_findings_bucket" {
#   bucket = "${var.name}-guardduty-findings-${data.aws_caller_identity.current.account_id}"
#   force_destroy = true # Only for dev/testing, ensures bucket can be deleted even if it contains objects
#   tags = {
#     Name        = "${var.name}-guardduty-findings-bucket"
#     Service     = "GuardDuty"
#   }
# }

# 3. AWS CloudTrail
# Create an S3 bucket for CloudTrail logs
resource "aws_s3_bucket" "cloudtrail_logs" {
  bucket        = "${var.name}-cloudtrail-logs-${data.aws_caller_identity.current.account_id}"
  force_destroy = true # Only for dev/testing, allows deleting bucket with objects

  tags = {
    Name    = "${var.name}-cloudtrail-logs-bucket"
    Service = "CloudTrail"
  }
}

# Enable versioning for log integrity
resource "aws_s3_bucket_versioning" "cloudtrail_logs_versioning" {
  bucket = aws_s3_bucket.cloudtrail_logs.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Enable encryption for logs at rest
resource "aws_s3_bucket_server_side_encryption_configuration" "cloudtrail_logs_encryption" {
  bucket = aws_s3_bucket.cloudtrail_logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Block public access for security (CIS Benchmark)
# These are the default settings of the aws_s3_bucket_public_access_block.
# Explicitly defined here for clarity for security project.
resource "aws_s3_bucket_public_access_block" "cloudtrail_logs_block" {
  bucket = aws_s3_bucket.cloudtrail_logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# S3 Bucket Policy to allow CloudTrail to write logs
resource "aws_s3_bucket_policy" "cloudtrail_bucket_policy" {
  bucket = aws_s3_bucket.cloudtrail_logs.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid    = "AWSCloudTrailAclCheck",
        Effect = "Allow",
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        },
        Action   = "s3:GetBucketAcl",
        Resource = "arn:aws:s3:::${aws_s3_bucket.cloudtrail_logs.id}"
      },
      {
        Sid    = "AWSCloudTrailWrite",
        Effect = "Allow",
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        },
        Action   = "s3:PutObject",
        Resource = "arn:aws:s3:::${aws_s3_bucket.cloudtrail_logs.id}/AWSLogs/${data.aws_caller_identity.current.account_id}/*",
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
          }
        }
      }
    ]
  })
}

resource "aws_cloudtrail" "main" {
  name                          = "${var.name}-cloudtrail"
  s3_bucket_name                = aws_s3_bucket.cloudtrail_logs.id
  is_multi_region_trail         = true  # Recommended for comprehensive logging
  include_global_service_events = true  # Recommended for comprehensive logging
  is_organization_trail         = false # Set to true if managing an AWS Organization
  enable_log_file_validation    = true  # Ensure log integrity (CIS Benchmark)

  # Explicit dependency to ensure the S3 bucket policy is fully applied before CloudTrail attempts to create the trail.
  depends_on = [
    aws_s3_bucket_policy.cloudtrail_bucket_policy
  ]

  # Optional: Enable CloudWatch Logs integration for real-time monitoring and alerting
  cloud_watch_logs_group_arn = "${aws_cloudwatch_log_group.cloudtrail_logs.arn}:*"
  cloud_watch_logs_role_arn  = aws_iam_role.cloudtrail_cloudwatch_role.arn

  tags = {
    Name    = "${var.name}-cloudtrail"
    Service = "CloudTrail"
  }
}

# CloudWatch Log Group for CloudTrail
resource "aws_cloudwatch_log_group" "cloudtrail_logs" {
  name              = "/aws/cloudtrail/${var.name}-cloudtrail"
  retention_in_days = 365 # CIS Benchmark: Define log retention periods for CloudTrail

  tags = {
    Name    = "${var.name}-cloudtrail-logs"
    Service = "CloudTrail"
  }
}

# IAM Role for CloudTrail to publish to CloudWatch Logs
resource "aws_iam_role" "cloudtrail_cloudwatch_role" {
  name = "${var.name}-cloudtrail-cloudwatch-role"
  assume_role_policy = jsonencode({
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name    = "${var.name}-cloudtrail-cloudwatch-role"
    Service = "CloudTrail"
  }
}

resource "aws_iam_role_policy" "cloudtrail_cloudwatch_policy" {
  name = "${var.name}-cloudtrail-cloudwatch-policy"
  role = aws_iam_role.cloudtrail_cloudwatch_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Resource = [
          "${aws_cloudwatch_log_group.cloudtrail_logs.arn}:*"
        ]
      }
    ]
  })
}

# Data source for current account ID to use in S3 bucket names and policies
data "aws_caller_identity" "current" {}
