variable "project" {
  description = "Project name used for resource naming"
  type        = string
  default     = "autocare"
}

variable "aws_region" {
  description = "AWS region to create the state bucket in"
  type        = string
  default     = "us-east-1"
}

variable "tags" {
  description = "Common tags applied to all resources"
  type        = map(string)
  default = {
    Project   = "autocare"
    ManagedBy = "terraform"
    Purpose   = "terraform-remote-state"
  }
}
