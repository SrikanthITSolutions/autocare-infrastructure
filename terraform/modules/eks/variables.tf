variable "project" {
  description = "Project name used for resource naming and tagging"
  type        = string
}

variable "environment" {
  description = "Deployment environment (e.g. dev, prod)"
  type        = string
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "kubernetes_version" {
  description = "Kubernetes version for the EKS control plane. Leave null to use whatever AWS currently defaults new EKS clusters to - avoids the cluster/node-group AMI pairing breaking every time AWS deprecates an old version."
  type        = string
  default     = null
}

variable "vpc_id" {
  description = "VPC ID the cluster is deployed into"
  type        = string
}

variable "control_plane_subnet_ids" {
  description = "Subnet IDs used for EKS control plane elastic network interfaces (private application subnets)"
  type        = list(string)
}

variable "node_subnet_ids" {
  description = "Subnet IDs used for EKS managed node group instances (private application subnets)"
  type        = list(string)
}

variable "cluster_role_arn" {
  description = "IAM role ARN for the EKS control plane"
  type        = string
}

variable "node_role_arn" {
  description = "IAM role ARN for EKS managed node group instances"
  type        = string
}

variable "alb_controller_policy_arn" {
  description = "IAM policy ARN to attach to the AWS Load Balancer Controller IRSA role"
  type        = string
}

variable "endpoint_private_access" {
  description = "Enable private access to the EKS API server endpoint"
  type        = bool
  default     = true
}

variable "endpoint_public_access" {
  description = "Enable public access to the EKS API server endpoint"
  type        = bool
  default     = true
}

variable "public_access_cidrs" {
  description = "CIDR blocks allowed to reach the public EKS API server endpoint. Restrict this to known IP ranges (e.g. office/VPN/CI) in production."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "node_instance_types" {
  description = "EC2 instance types for the managed node group"
  type        = list(string)
  default     = ["t3.medium"]
}

variable "node_capacity_type" {
  description = "Capacity type for the managed node group (ON_DEMAND or SPOT)"
  type        = string
  default     = "ON_DEMAND"
}

variable "node_disk_size" {
  description = "Root EBS volume size (GiB) for worker nodes"
  type        = number
  default     = 20
}

variable "node_desired_size" {
  description = "Desired number of worker nodes"
  type        = number
  default     = 2
}

variable "node_min_size" {
  description = "Minimum number of worker nodes (Auto Scaling)"
  type        = number
  default     = 2
}

variable "node_max_size" {
  description = "Maximum number of worker nodes (Auto Scaling)"
  type        = number
  default     = 4
}

variable "log_retention_days" {
  description = "CloudWatch Logs retention period for the EKS control plane log group"
  type        = number
  default     = 90
}

variable "tags" {
  description = "Common tags applied to all resources"
  type        = map(string)
  default     = {}
}
