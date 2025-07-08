# outputs.tf - Security Monitoring

output "security_hub_arn" {
  description = "The ARN of the AWS Security Hub account."
  value       = aws_securityhub_account.main.arn
}

output "guardduty_detector_id" {
  description = "The ID of the GuardDuty detector."
  value       = aws_guardduty_detector.main.id
}

output "cloudtrail_arn" {
  description = "The ARN of the CloudTrail trail."
  value       = aws_cloudtrail.main.id
}

output "cloudtrail_s3_bucket_name" {
  description = "The name of the S3 bucket where CloudTrail logs are stored."
  value       = aws_s3_bucket.cloudtrail_logs.bucket
}
