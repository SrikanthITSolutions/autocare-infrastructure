variable "project" {
  description = "Project name used for resource naming and tagging"
  type        = string
}

variable "environment" {
  description = "Deployment environment (e.g. dev, prod)"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID to enable flow logs for"
  type        = string
}

variable "eks_cluster_name" {
  description = "Name of the EKS cluster (for reference/tagging)"
  type        = string
}

variable "rds_instance_id" {
  description = "RDS instance identifier to attach CloudWatch alarms to"
  type        = string
}

variable "nat_gateway_ids" {
  description = "NAT Gateway IDs to attach CloudWatch alarms to"
  type        = list(string)
  default     = []
}

variable "alarm_sns_email" {
  description = "Email address to subscribe to infrastructure alarm notifications. Leave empty to skip creating a subscription."
  type        = string
  default     = ""
}

variable "flow_log_retention_days" {
  description = "CloudWatch Logs retention period for VPC flow logs"
  type        = number
  default     = 90
}

variable "tags" {
  description = "Common tags applied to all resources"
  type        = map(string)
  default     = {}
}
