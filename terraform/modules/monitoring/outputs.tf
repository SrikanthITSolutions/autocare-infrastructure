output "flow_log_group_name" {
  description = "CloudWatch Logs group name receiving VPC flow logs"
  value       = aws_cloudwatch_log_group.flow_logs.name
}

output "sns_topic_arn" {
  description = "ARN of the SNS topic used for infrastructure alarm notifications"
  value       = aws_sns_topic.alarms.arn
}
