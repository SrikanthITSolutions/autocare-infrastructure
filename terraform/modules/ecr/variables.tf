variable "project" {
  description = "Project name used for resource naming and tagging"
  type        = string
}

variable "environment" {
  description = "Deployment environment (e.g. dev, prod)"
  type        = string
}

variable "repository_name" {
  description = "Base name of the ECR repository (final name is <project>-<environment>-<repository_name>)"
  type        = string
  default     = "autocare"
}

variable "image_tag_mutability" {
  description = "Whether image tags can be overwritten (MUTABLE or IMMUTABLE)"
  type        = string
  default     = "IMMUTABLE"
}

variable "scan_on_push" {
  description = "Enable automatic vulnerability scanning when images are pushed"
  type        = bool
  default     = true
}

variable "kms_key_arn" {
  description = "Optional KMS key ARN for repository encryption; when null, AES256 (SSE-S3 managed) encryption is used"
  type        = string
  default     = null
}

variable "max_tagged_image_count" {
  description = "Maximum number of tagged images to retain before older ones expire"
  type        = number
  default     = 10
}

variable "untagged_image_expiry_days" {
  description = "Number of days after which untagged images expire"
  type        = number
  default     = 7
}

variable "tags" {
  description = "Common tags applied to all resources"
  type        = map(string)
  default     = {}
}
