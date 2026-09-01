output "eks_cluster_role_arn" {
  description = "ARN of the IAM role used by the EKS control plane"
  value       = aws_iam_role.eks_cluster.arn
}

output "eks_node_role_arn" {
  description = "ARN of the IAM role used by EKS managed node group instances"
  value       = aws_iam_role.eks_node.arn
}

output "eks_node_role_name" {
  description = "Name of the IAM role used by EKS managed node group instances"
  value       = aws_iam_role.eks_node.name
}

output "alb_controller_policy_arn" {
  description = "ARN of the IAM policy for the AWS Load Balancer Controller"
  value       = aws_iam_policy.alb_controller.arn
}
